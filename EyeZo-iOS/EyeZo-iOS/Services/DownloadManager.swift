import Foundation
import CoreData
import AVFoundation
import UIKit
import Combine

@MainActor
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadQueue: [DownloadItem] = [] {
        didSet { persistPendingDownloads() }
    }
    @Published private(set) var currentDownload: DownloadItem? {
        didSet {
            if currentDownload?.video.urlPath != oldValue?.video.urlPath {
                persistPendingDownloads()
            }
        }
    }
    @Published private(set) var failedDownloads: [DownloadItem] = []
    @Published private(set) var downloadStates: [String: DownloadState] = [:] // Key: video.urlPath

    private var backgroundSession: URLSession!
    private let coreDataManager = CoreDataManager.shared
    private let apiService = APIService()
    private let fileManager = FileManager.default

    // Storage paths
    private var videosDirectory: URL!
    private var thumbnailsDirectory: URL!
    private var pendingDownloadsFile: URL!
    private var isRestoringPendingDownloads = false

    // Background completion handler
    var backgroundCompletionHandler: (() -> Void)?

    // Task mapping for progress tracking
    private var taskToItemMapping: [Int: UUID] = [:] // TaskIdentifier -> DownloadItem.id

    private override init() {
        super.init()
        setupStorageDirectories()
        setupBackgroundSession()
        loadDownloadStates()
        restorePendingDownloads()
    }

    // MARK: - Setup

    private func setupStorageDirectories() {
        let baseURL = DownloadedVideo.downloadsDirectory
        videosDirectory = baseURL.appendingPathComponent("videos")
        thumbnailsDirectory = baseURL.appendingPathComponent("thumbnails")
        pendingDownloadsFile = baseURL.appendingPathComponent("pending-downloads.json")

        do {
            try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        } catch {
            // Directory creation failed - downloads will fail but app won't crash
        }
    }

    private func setupBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.eyezo.background-downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600

        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    private func loadDownloadStates() {
        let downloadedVideos = getAllDownloadedVideos()
        for video in downloadedVideos {
            downloadStates[video.urlPath] = .completed
        }
    }

    // MARK: - Public API

    func addToDownloadQueue(video: VideoItem, serverURL: URL) {
        addToDownloadQueue(videos: [video], serverURL: serverURL)
    }

    func addToDownloadQueue(videos: [VideoItem], serverURL: URL) {
        var newItems: [DownloadItem] = []

        for video in videos {
            // Skip anything already downloaded
            if isVideoDownloaded(urlPath: video.urlPath) {
                downloadStates[video.urlPath] = .completed
                continue
            }

            // Skip anything already queued or downloading
            if isPending(urlPath: video.urlPath) || newItems.contains(where: { $0.video.urlPath == video.urlPath }) {
                continue
            }

            failedDownloads.removeAll { $0.video.urlPath == video.urlPath }
            newItems.append(DownloadItem(video: video, serverURL: serverURL))
            downloadStates[video.urlPath] = .queued
        }

        guard !newItems.isEmpty else { return }
        downloadQueue.append(contentsOf: newItems)

        // Start download if nothing is downloading
        if currentDownload == nil {
            Task {
                await startNextDownload()
            }
        }
    }

    func retryFailedDownload(for videoPath: String) {
        guard let item = failedDownloads.first(where: { $0.video.urlPath == videoPath }) else { return }
        addToDownloadQueue(video: item.video, serverURL: item.serverURL)
    }

    func cancelDownload(for videoPath: String) {
        // Cancel if currently downloading
        if let current = currentDownload, current.video.urlPath == videoPath {
            if let task = current.downloadTask {
                task.cancel()
                taskToItemMapping.removeValue(forKey: task.taskIdentifier)
            }
            currentDownload = nil
            downloadStates[videoPath] = nil

            // Start next download
            Task {
                await startNextDownload()
            }
            return
        }

        // Remove from queue if queued
        if let index = downloadQueue.firstIndex(where: { $0.video.urlPath == videoPath }) {
            downloadQueue.remove(at: index)
            downloadStates[videoPath] = nil
        }

        // Forget a failed download
        if let index = failedDownloads.firstIndex(where: { $0.video.urlPath == videoPath }) {
            failedDownloads.remove(at: index)
            downloadStates[videoPath] = nil
        }
    }

    /// Cancels every queued, downloading, or failed download under `folder`
    func cancelDownloads(inFolder folder: [String]) {
        let paths = ([currentDownload].compactMap { $0 } + downloadQueue + failedDownloads)
            .map(\.video.urlPath)
            .filter { DownloadTree.urlPath($0, isInFolder: folder) }

        for path in paths {
            cancelDownload(for: path)
        }
    }

    /// Deletes every downloaded video under `folder` and cancels anything still pending there
    func deleteDownloads(inFolder folder: [String]) {
        cancelDownloads(inFolder: folder)

        for video in getAllDownloadedVideos() where DownloadTree.urlPath(video.urlPath, isInFolder: folder) {
            deleteDownloadedVideo(video)
        }
    }

    /// 1-based position in the queue for a waiting download, nil otherwise
    func queuePosition(for videoPath: String) -> Int? {
        downloadQueue.firstIndex { $0.video.urlPath == videoPath }.map { $0 + 1 }
    }

    func isPending(urlPath: String) -> Bool {
        currentDownload?.video.urlPath == urlPath || downloadQueue.contains { $0.video.urlPath == urlPath }
    }

    func deleteDownloadedVideo(_ downloadedVideo: DownloadedVideo) {
        // Extract data before deletion (to avoid using deleted object)
        let videoURL = downloadedVideo.localFileURL
        let thumbnailURL = downloadedVideo.thumbnailURL
        let urlPath = downloadedVideo.urlPath

        // Delete from CoreData first
        let context = coreDataManager.viewContext
        context.delete(downloadedVideo)

        do {
            // Save context to commit the deletion
            try context.save()
        } catch {
            print("Error deleting video from CoreData: \(error)")
            return
        }

        // Now delete files from disk
        try? fileManager.removeItem(at: videoURL)

        // Delete thumbnail if exists
        if let thumbnailURL = thumbnailURL {
            try? fileManager.removeItem(at: thumbnailURL)
        }

        // Update state
        downloadStates[urlPath] = nil
    }

    func isVideoDownloaded(urlPath: String) -> Bool {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<DownloadedVideo> = DownloadedVideo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "urlPath == %@", urlPath)

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            return false
        }
    }

    func getDownloadState(for videoPath: String) -> DownloadState {
        return downloadStates[videoPath] ?? .none
    }

    func getAllDownloadedVideos() -> [DownloadedVideo] {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<DownloadedVideo> = DownloadedVideo.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "videoName", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        ]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            return []
        }
    }

    func getTotalStorageUsed() -> Int64 {
        let downloadedVideos = getAllDownloadedVideos()
        return downloadedVideos.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - Private Download Logic

    private func startNextDownload() async {
        guard currentDownload == nil, !downloadQueue.isEmpty else {
            return
        }

        let item = downloadQueue.removeFirst()
        currentDownload = item
        downloadStates[item.video.urlPath] = .downloading(progress: 0.0)

        await downloadVideo(item)
    }

    private func downloadVideo(_ item: DownloadItem) async {
        let videoURL = apiService.getVideoURL(serverURL: item.serverURL, videoPath: item.video.urlPath)

        let task = backgroundSession.downloadTask(with: videoURL)
        taskToItemMapping[task.taskIdentifier] = item.id

        var updatedItem = item
        updatedItem.downloadTask = task
        currentDownload = updatedItem

        task.resume()
    }

    private func handleDownloadCompletion(task: URLSessionDownloadTask, movedLocation: Result<URL, FileError>) async {
        guard let item = currentItem(for: task) else {
            // Not ours (e.g. cancelled) - don't leave the file behind
            if case .success(let url) = movedLocation {
                try? fileManager.removeItem(at: url)
            }
            return
        }

        // Check if file move was successful
        let tempURL: URL
        switch movedLocation {
        case .success(let url):
            tempURL = url
        case .failure(let error):
            let errorMsg: String
            if case .message(let msg) = error {
                errorMsg = msg
            } else {
                errorMsg = "Failed to save file"
            }
            recordFailure(item, error: errorMsg)
            await startNextDownload()
            return
        }

        // Rename with proper extension
        guard let finalURL = renameWithProperExtension(tempURL: tempURL, for: item) else {
            recordFailure(item, error: "Failed to rename file")
            await startNextDownload()
            return
        }

        // Download thumbnail
        let thumbnailPath = await downloadThumbnail(for: item.video, serverURL: item.serverURL)

        // The server only knows the duration once it has scanned the file's metadata
        var duration = item.video.duration ?? 0
        if duration <= 0 {
            duration = await localDuration(of: finalURL)
        }

        // Save to CoreData
        saveToDatabase(item, localURL: finalURL, thumbnailPath: thumbnailPath, duration: duration)

        // Update state
        downloadStates[item.video.urlPath] = .completed
        taskToItemMapping.removeValue(forKey: task.taskIdentifier)
        // The download may have been cancelled (and the next one started) while the thumbnail loaded
        if currentDownload?.id == item.id {
            currentDownload = nil
        }

        // Start next download
        await startNextDownload()
    }

    private func recordFailure(_ item: DownloadItem, error: String) {
        var failedItem = item
        failedItem.downloadTask = nil
        failedDownloads.removeAll { $0.video.urlPath == item.video.urlPath }
        failedDownloads.append(failedItem)
        downloadStates[item.video.urlPath] = .failed(error: error)
        currentDownload = nil
    }

    /// The current download a session task belongs to. Tasks that outlived a
    /// previous launch have no mapping yet, so they're matched by URL and
    /// adopted if they belong to a pending download.
    private func currentItem(for task: URLSessionTask) -> DownloadItem? {
        if let itemId = taskToItemMapping[task.taskIdentifier] {
            guard let item = currentDownload, item.id == itemId else { return nil }
            return item
        }

        guard let taskURL = task.originalRequest?.url else { return nil }
        let matches: (DownloadItem) -> Bool = { [apiService] item in
            apiService.getVideoURL(serverURL: item.serverURL, videoPath: item.video.urlPath) == taskURL
        }

        if let current = currentDownload, current.downloadTask == nil, matches(current) {
            adopt(task, for: current)
            return currentDownload
        }

        if currentDownload == nil, let index = downloadQueue.firstIndex(where: matches) {
            let item = downloadQueue.remove(at: index)
            adopt(task, for: item)
            return currentDownload
        }

        return nil
    }

    private func adopt(_ task: URLSessionTask, for item: DownloadItem) {
        var adoptedItem = item
        adoptedItem.downloadTask = task as? URLSessionDownloadTask
        taskToItemMapping[task.taskIdentifier] = item.id
        currentDownload = adoptedItem
        downloadStates[item.video.urlPath] = .downloading(progress: 0.0)
    }

    // MARK: - Queue Persistence

    private struct PersistedDownload: Codable {
        let video: VideoItem
        let serverURL: URL
    }

    private func persistPendingDownloads() {
        guard !isRestoringPendingDownloads else { return }

        let items = [currentDownload].compactMap { $0 } + downloadQueue
        let persisted = items.map { PersistedDownload(video: $0.video, serverURL: $0.serverURL) }

        if persisted.isEmpty {
            try? fileManager.removeItem(at: pendingDownloadsFile)
        } else if let data = try? JSONEncoder().encode(persisted) {
            try? data.write(to: pendingDownloadsFile, options: .atomic)
        }
    }

    /// Re-queues downloads that were pending when the app last quit. A task
    /// still running in the background session is adopted rather than restarted;
    /// any other leftover task is cancelled.
    private func restorePendingDownloads() {
        guard let data = try? Data(contentsOf: pendingDownloadsFile),
              let persisted = try? JSONDecoder().decode([PersistedDownload].self, from: data) else { return }

        isRestoringPendingDownloads = true
        let items = persisted
            .filter { !isVideoDownloaded(urlPath: $0.video.urlPath) }
            .map { DownloadItem(video: $0.video, serverURL: $0.serverURL) }
        downloadQueue = items
        for item in items {
            downloadStates[item.video.urlPath] = .queued
        }
        isRestoringPendingDownloads = false

        backgroundSession.getAllTasks { [weak self] tasks in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                for task in tasks where task.state == .running || task.state == .suspended {
                    if self.currentItem(for: task) == nil {
                        task.cancel()
                    }
                }

                await self.startNextDownload()
            }
        }
    }

    private func renameWithProperExtension(tempURL: URL, for item: DownloadItem) -> URL? {
        let fileExtension = item.video.extension.hasPrefix(".") ? item.video.extension : ".\(item.video.extension)"
        let finalURL = tempURL.deletingPathExtension().appendingPathExtension(fileExtension.dropFirst().description)

        do {
            try fileManager.moveItem(at: tempURL, to: finalURL)
            return finalURL
        } catch {
            // If rename fails, just use the temp URL
            return tempURL
        }
    }

    private func handleDownloadProgress(task: URLSessionDownloadTask, progress: Double) {
        guard let item = currentItem(for: task) else {
            return
        }

        // Clamp progress between 0 and 1
        let clampedProgress = min(max(progress, 0.0), 1.0)
        downloadStates[item.video.urlPath] = .downloading(progress: clampedProgress)
    }

    private func handleDownloadError(task: URLSessionTask, error: Error) async {
        guard let item = currentItem(for: task) else {
            return
        }

        // Provide more detailed error message
        let errorMsg: String
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                errorMsg = "No internet connection"
            case NSURLErrorTimedOut:
                errorMsg = "Download timed out"
            case NSURLErrorCancelled:
                errorMsg = "Download was cancelled"
            case NSURLErrorNetworkConnectionLost:
                errorMsg = "Network connection lost"
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                errorMsg = "Cannot connect to server"
            default:
                errorMsg = "Network error: \(error.localizedDescription)"
            }
        } else {
            errorMsg = "Download failed: \(error.localizedDescription)"
        }

        taskToItemMapping.removeValue(forKey: task.taskIdentifier)
        recordFailure(item, error: errorMsg)

        // Start next download
        await startNextDownload()
    }

    private func downloadThumbnail(for video: VideoItem, serverURL: URL) async -> String? {
        guard let thumbnailURL = apiService.getThumbnailURL(serverURL: serverURL, videoPath: video.urlPath) else {
            print("⚠️ Thumbnail download failed for '\(video.name)': No thumbnail URL available")
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: thumbnailURL)

            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("⚠️ Thumbnail download failed for '\(video.name)': HTTP \(httpResponse.statusCode)")
                    return nil
                }
            }

            guard let image = UIImage(data: data) else {
                print("⚠️ Thumbnail download failed for '\(video.name)': Could not create image from data (size: \(data.count) bytes)")
                return nil
            }

            // Compress image
            guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
                print("⚠️ Thumbnail download failed for '\(video.name)': Could not compress image to JPEG")
                return nil
            }

            // Save to thumbnails directory
            let uuid = UUID().uuidString
            let thumbnailPath = thumbnailsDirectory.appendingPathComponent("\(uuid).jpg")

            try jpegData.write(to: thumbnailPath)
            print("✅ Thumbnail downloaded successfully for '\(video.name)' (saved to: \(thumbnailPath.lastPathComponent))")
            // Store just the file name; see DownloadedVideo.downloadsDirectory
            return thumbnailPath.lastPathComponent
        } catch {
            print("⚠️ Thumbnail download failed for '\(video.name)': \(error.localizedDescription)")
            return nil
        }
    }

    // Public method to retry downloading thumbnail for an existing video
    func retryThumbnailDownload(for downloadedVideo: DownloadedVideo) async {
        // Reconstruct server URL and video info
        guard let serverURL = URL(string: downloadedVideo.serverURL) else {
            print("⚠️ Cannot retry thumbnail: Invalid server URL")
            return
        }

        // Create a temporary VideoItem to pass to downloadThumbnail
        let tempVideoItem = VideoItem(
            name: downloadedVideo.videoName,
            path: downloadedVideo.originalPath,
            relativePath: downloadedVideo.originalPath,
            urlPath: downloadedVideo.urlPath,
            size: downloadedVideo.fileSize,
            modified: downloadedVideo.downloadedDate.timeIntervalSince1970,
            extension: downloadedVideo.fileExtension,
            mimeType: downloadedVideo.mimeType,
            thumbnailUrl: nil,
            duration: downloadedVideo.duration,
            watchPosition: nil,
            lastWatched: nil
        )

        print("🔄 Retrying thumbnail download for '\(downloadedVideo.videoName)'...")

        if let thumbnailPath = await downloadThumbnail(for: tempVideoItem, serverURL: serverURL) {
            // Update CoreData with new thumbnail path
            downloadedVideo.thumbnailPath = thumbnailPath
            coreDataManager.saveContext()
            print("✅ Thumbnail retry successful for '\(downloadedVideo.videoName)'")
        } else {
            print("❌ Thumbnail retry failed for '\(downloadedVideo.videoName)'")
        }
    }

    /// Reads the duration from the downloaded file itself; 0 if it can't be determined
    private func localDuration(of url: URL) async -> Double {
        guard let duration = try? await AVURLAsset(url: url).load(.duration) else { return 0 }
        let seconds = duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }

    /// Fills in durations for downloads saved without one (the watch progress bar needs it)
    func backfillMissingDurations() async {
        var didChange = false

        for video in getAllDownloadedVideos() where video.duration <= 0 {
            let duration = await localDuration(of: video.localFileURL)
            guard duration > 0, !video.isDeleted, video.managedObjectContext != nil else { continue }
            video.duration = duration
            didChange = true
        }

        if didChange {
            coreDataManager.saveContext()
        }
    }

    // Batch retry for all videos missing thumbnails
    func retryMissingThumbnails() async {
        let videos = getAllDownloadedVideos()
        let videosWithoutThumbnails = videos.filter { $0.thumbnailPath == nil }

        print("🔄 Found \(videosWithoutThumbnails.count) videos without thumbnails. Starting batch retry...")

        for video in videosWithoutThumbnails {
            await retryThumbnailDownload(for: video)
        }

        print("✅ Batch thumbnail retry complete")
    }

    private func saveToDatabase(_ item: DownloadItem, localURL: URL, thumbnailPath: String?, duration: Double) {
        let context = coreDataManager.viewContext
        let downloadedVideo = DownloadedVideo(context: context)

        downloadedVideo.id = UUID()
        downloadedVideo.videoName = item.video.name
        downloadedVideo.originalPath = item.video.path
        downloadedVideo.urlPath = item.video.urlPath
        downloadedVideo.fileSize = item.video.size
        downloadedVideo.localFilePath = localURL.lastPathComponent
        downloadedVideo.thumbnailPath = thumbnailPath
        downloadedVideo.duration = duration
        downloadedVideo.downloadedDate = Date()
        downloadedVideo.fileExtension = item.video.extension
        downloadedVideo.mimeType = item.video.mimeType
        downloadedVideo.serverURL = item.serverURL.absoluteString
        // Watch progress starts fresh: offline progress is tracked separately from the server's

        coreDataManager.saveContext()
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // CRITICAL: Must move file immediately before this delegate method returns
        // The temp file gets deleted by the system after this method completes
        let taskId = downloadTask.taskIdentifier

        // Move file synchronously in this nonisolated context
        let movedLocation = moveDownloadedFileImmediately(from: location, taskId: taskId)

        Task { @MainActor [weak self] in
            await self?.handleDownloadCompletion(task: downloadTask, movedLocation: movedLocation)
        }
    }

    enum FileError: Error {
        case message(String)
    }

    nonisolated private func moveDownloadedFileImmediately(from tempURL: URL, taskId: Int) -> Result<URL, FileError> {
        let fileManager = FileManager.default
        let uuid = UUID().uuidString

        // Get videos directory path
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return .failure(.message("Could not access application support directory"))
        }

        let videosDir = appSupportURL
            .appendingPathComponent("com.eyezo.app/downloads/videos")

        // Create directory if needed
        try? fileManager.createDirectory(at: videosDir, withIntermediateDirectories: true)

        // Use task ID temporarily since we don't have the video extension yet
        let destinationURL = videosDir.appendingPathComponent("\(uuid)_\(taskId).tmp")

        do {
            // Use moveItem instead of copyItem - it's faster and the temp file will be deleted anyway
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            return .success(destinationURL)
        } catch {
            return .failure(.message("Failed to save file: \(error.localizedDescription)"))
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Handle case where server doesn't send Content-Length (totalBytesExpectedToWrite == -1)
        let progress: Double

        if totalBytesExpectedToWrite > 0 {
            // Normal case: we know the total size
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            // Server didn't send Content-Length, show indeterminate progress
            // Use a pulsing animation by showing 50% (we'll update the UI to handle this)
            progress = 0.5
        }

        Task { @MainActor [weak self] in
            self?.handleDownloadProgress(task: downloadTask, progress: progress)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor [weak self] in
                await self?.handleDownloadError(task: task, error: error)
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            backgroundCompletionHandler?()
            backgroundCompletionHandler = nil
        }
    }
}
