import Foundation
import CoreData
import UIKit
import Combine

@MainActor
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadQueue: [DownloadItem] = []
    @Published private(set) var currentDownload: DownloadItem?
    @Published private(set) var downloadStates: [String: DownloadState] = [:] // Key: video.urlPath

    private var backgroundSession: URLSession!
    private let coreDataManager = CoreDataManager.shared
    private let apiService = APIService()
    private let fileManager = FileManager.default

    // Storage paths
    private var videosDirectory: URL!
    private var thumbnailsDirectory: URL!

    // Background completion handler
    var backgroundCompletionHandler: (() -> Void)?

    // Task mapping for progress tracking
    private var taskToItemMapping: [Int: UUID] = [:] // TaskIdentifier -> DownloadItem.id

    private override init() {
        super.init()
        setupStorageDirectories()
        setupBackgroundSession()
        loadDownloadStates()
    }

    // MARK: - Setup

    private func setupStorageDirectories() {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Application Support directory")
        }

        let baseURL = appSupportURL.appendingPathComponent("com.eyezo.app/downloads")
        videosDirectory = baseURL.appendingPathComponent("videos")
        thumbnailsDirectory = baseURL.appendingPathComponent("thumbnails")

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
        // Check if already downloaded
        if isVideoDownloaded(urlPath: video.urlPath) {
            downloadStates[video.urlPath] = .alreadyDownloaded
            return
        }

        // Check if already in queue
        if downloadQueue.contains(where: { $0.video.urlPath == video.urlPath }) {
            return
        }

        // Check if currently downloading
        if currentDownload?.video.urlPath == video.urlPath {
            return
        }

        // Add to queue
        var item = DownloadItem(video: video, serverURL: serverURL)
        item.state = .queued
        downloadQueue.append(item)
        downloadStates[video.urlPath] = .queued

        // Start download if nothing is downloading
        if currentDownload == nil {
            Task {
                await startNextDownload()
            }
        }
    }

    func cancelDownload(for videoPath: String) {
        // Cancel if currently downloading
        if let current = currentDownload, current.video.urlPath == videoPath {
            current.downloadTask?.cancel()
            currentDownload = nil
            downloadStates[videoPath] = .none

            // Start next download
            Task {
                await startNextDownload()
            }
            return
        }

        // Remove from queue if queued
        if let index = downloadQueue.firstIndex(where: { $0.video.urlPath == videoPath }) {
            downloadQueue.remove(at: index)
            downloadStates[videoPath] = .none
        }
    }

    func deleteDownloadedVideo(_ downloadedVideo: DownloadedVideo) {
        // Extract data before deletion (to avoid using deleted object)
        let localFilePath = downloadedVideo.localFilePath
        let thumbnailPath = downloadedVideo.thumbnailPath
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
        let videoURL = URL(fileURLWithPath: localFilePath)
        try? fileManager.removeItem(at: videoURL)

        // Delete thumbnail if exists
        if let thumbnailPath = thumbnailPath {
            let thumbnailURL = URL(fileURLWithPath: thumbnailPath)
            try? fileManager.removeItem(at: thumbnailURL)
        }

        // Update state
        downloadStates[urlPath] = .none
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
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "downloadedDate", ascending: false)]

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
        guard let itemId = taskToItemMapping[task.taskIdentifier],
              let item = currentDownload, item.id == itemId else {
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
            downloadStates[item.video.urlPath] = .failed(error: errorMsg)
            currentDownload = nil
            await startNextDownload()
            return
        }

        // Rename with proper extension
        guard let finalURL = renameWithProperExtension(tempURL: tempURL, for: item) else {
            downloadStates[item.video.urlPath] = .failed(error: "Failed to rename file")
            currentDownload = nil
            await startNextDownload()
            return
        }

        // Download thumbnail
        let thumbnailPath = await downloadThumbnail(for: item.video, serverURL: item.serverURL)

        // Save to CoreData
        saveToDatabase(item, localURL: finalURL, thumbnailPath: thumbnailPath)

        // Update state
        downloadStates[item.video.urlPath] = .completed
        taskToItemMapping.removeValue(forKey: task.taskIdentifier)
        currentDownload = nil

        // Start next download
        await startNextDownload()
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
        guard let itemId = taskToItemMapping[task.taskIdentifier],
              let item = currentDownload, item.id == itemId else {
            return
        }

        // Clamp progress between 0 and 1
        let clampedProgress = min(max(progress, 0.0), 1.0)
        downloadStates[item.video.urlPath] = .downloading(progress: clampedProgress)
    }

    private func handleDownloadError(task: URLSessionTask, error: Error) async {
        guard let itemId = taskToItemMapping[task.taskIdentifier],
              let item = currentDownload, item.id == itemId else {
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

        downloadStates[item.video.urlPath] = .failed(error: errorMsg)
        taskToItemMapping.removeValue(forKey: task.taskIdentifier)
        currentDownload = nil

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
            return thumbnailPath.path
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
            let context = coreDataManager.viewContext
            downloadedVideo.thumbnailPath = thumbnailPath
            coreDataManager.saveContext()
            print("✅ Thumbnail retry successful for '\(downloadedVideo.videoName)'")
        } else {
            print("❌ Thumbnail retry failed for '\(downloadedVideo.videoName)'")
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

    private func saveToDatabase(_ item: DownloadItem, localURL: URL, thumbnailPath: String?) {
        let context = coreDataManager.viewContext
        let downloadedVideo = DownloadedVideo(context: context)

        downloadedVideo.id = UUID()
        downloadedVideo.videoName = item.video.name
        downloadedVideo.originalPath = item.video.path
        downloadedVideo.urlPath = item.video.urlPath
        downloadedVideo.fileSize = item.video.size
        downloadedVideo.localFilePath = localURL.path
        downloadedVideo.thumbnailPath = thumbnailPath
        downloadedVideo.duration = item.video.duration ?? 0
        downloadedVideo.downloadedDate = Date()
        downloadedVideo.fileExtension = item.video.extension
        downloadedVideo.mimeType = item.video.mimeType
        downloadedVideo.serverURL = item.serverURL.absoluteString

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
