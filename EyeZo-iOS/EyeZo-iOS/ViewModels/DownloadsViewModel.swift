import Foundation
import Combine
import CoreData

@MainActor
class DownloadsViewModel: ObservableObject {
    @Published private(set) var downloadedVideos: [DownloadedVideo] = []
    /// Downloaded and pending videos together; the folder tree is derived from these
    @Published private(set) var entries: [DownloadEntry] = []
    @Published private(set) var totalStorageUsed: Int64 = 0

    private let downloadManager = DownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var previousStates: [String: DownloadState] = [:]

    init() {
        // Observe download state changes
        downloadManager.$downloadStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                guard let self = self else { return }

                // Reload downloaded videos when any download newly completes
                let hasNewCompletion = states.contains { urlPath, state in
                    guard case .completed = state else { return false }
                    if case .completed = self.previousStates[urlPath] { return false }
                    return true
                }
                self.previousStates = states

                if hasNewCompletion {
                    self.reloadDownloadedVideos()
                } else {
                    self.rebuildEntries()
                }
            }
            .store(in: &cancellables)

        // Observe queue changes
        Publishers.Merge3(
            downloadManager.$currentDownload.map { _ in () },
            downloadManager.$downloadQueue.map { _ in () },
            downloadManager.$failedDownloads.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            self?.rebuildEntries()
        }
        .store(in: &cancellables)
    }

    var formattedTotalSize: String {
        let bytes = Double(totalStorageUsed)

        if bytes == 0 {
            return "0 MB"
        }

        let gb = bytes / (1024 * 1024 * 1024)
        let mb = bytes / (1024 * 1024)
        let kb = bytes / 1024

        if gb >= 10 {
            // 10+ GB: Show whole GB (e.g., "12 GB")
            return String(format: "%.0f GB", gb)
        } else if gb >= 1 {
            // 1-10 GB: Show one decimal (e.g., "2.3 GB")
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            // 1+ MB: Show whole MB (e.g., "456 MB")
            return String(format: "%.0f MB", mb)
        } else if kb >= 1 {
            // 1+ KB: Show whole KB (e.g., "123 KB")
            return String(format: "%.0f KB", kb)
        } else {
            // Less than 1 KB: Show bytes
            return String(format: "%.0f B", bytes)
        }
    }

    func loadDownloadedVideos() async {
        reloadDownloadedVideos()
        await downloadManager.backfillMissingDurations()
    }

    func deleteVideo(_ video: DownloadedVideo) {
        // Extract object ID before deletion
        let objectID = video.objectID

        // Perform deletion
        downloadManager.deleteDownloadedVideo(video)

        // Remove using objectID comparison (works even for deleted objects)
        downloadedVideos.removeAll { $0.objectID == objectID }

        // Recalculate storage
        totalStorageUsed = downloadManager.getTotalStorageUsed()
        rebuildEntries()
    }

    func deleteFolder(_ folder: [String]) {
        downloadManager.deleteDownloads(inFolder: folder)
        reloadDownloadedVideos()
    }

    func cancelDownload(_ urlPath: String) {
        downloadManager.cancelDownload(for: urlPath)
    }

    func cancelDownloads(inFolder folder: [String]) {
        downloadManager.cancelDownloads(inFolder: folder)
    }

    func retryDownload(_ urlPath: String) {
        downloadManager.retryFailedDownload(for: urlPath)
    }

    func retryMissingThumbnails() async {
        await downloadManager.retryMissingThumbnails()
        reloadDownloadedVideos()
    }

    var hasVideosWithoutThumbnails: Bool {
        downloadedVideos.contains { $0.thumbnailPath == nil }
    }

    private func reloadDownloadedVideos() {
        downloadedVideos = downloadManager.getAllDownloadedVideos()
        totalStorageUsed = downloadManager.getTotalStorageUsed()
        rebuildEntries()
    }

    private func rebuildEntries() {
        var result = downloadedVideos.map(DownloadEntry.downloaded)
        var seen = Set(downloadedVideos.map(\.urlPath))

        let pendingItems = [downloadManager.currentDownload].compactMap { $0 }
            + downloadManager.downloadQueue
            + downloadManager.failedDownloads

        for item in pendingItems where !seen.contains(item.video.urlPath) {
            seen.insert(item.video.urlPath)
            result.append(.pending(PendingDownload(
                video: item.video,
                serverURL: item.serverURL,
                state: downloadManager.getDownloadState(for: item.video.urlPath),
                queuePosition: downloadManager.queuePosition(for: item.video.urlPath)
            )))
        }

        entries = result
    }
}
