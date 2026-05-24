import Foundation
import Combine
import CoreData

struct InProgressDownload: Identifiable {
    let id = UUID()
    let video: VideoItem
    let state: DownloadState
}

@MainActor
class DownloadsViewModel: ObservableObject {
    @Published private(set) var downloadedVideos: [DownloadedVideo] = []
    @Published private(set) var inProgressDownloads: [InProgressDownload] = []
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

                self.updateInProgressDownloads()

                // Check if any download just transitioned to completed
                for (urlPath, state) in states {
                    if case .completed = state {
                        // Check if this is a new completion (wasn't completed before)
                        let wasCompleted: Bool
                        if let previousState = self.previousStates[urlPath] {
                            if case .completed = previousState {
                                wasCompleted = true
                            } else {
                                wasCompleted = false
                            }
                        } else {
                            wasCompleted = false
                        }

                        if !wasCompleted {
                            // New completion detected - reload downloaded videos
                            Task {
                                await self.loadDownloadedVideos()
                            }
                            break
                        }
                    }
                }

                // Update previous states
                self.previousStates = states
            }
            .store(in: &cancellables)

        // Observe current download changes
        downloadManager.$currentDownload
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateInProgressDownloads()
            }
            .store(in: &cancellables)

        // Observe queue changes
        downloadManager.$downloadQueue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateInProgressDownloads()
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
        downloadedVideos = downloadManager.getAllDownloadedVideos()
        totalStorageUsed = downloadManager.getTotalStorageUsed()
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
    }

    func retryMissingThumbnails() async {
        await downloadManager.retryMissingThumbnails()
        await loadDownloadedVideos()
    }

    var hasVideosWithoutThumbnails: Bool {
        downloadedVideos.contains { $0.thumbnailPath == nil }
    }

    private func updateInProgressDownloads() {
        var inProgress: [InProgressDownload] = []

        // Add current download
        if let current = downloadManager.currentDownload {
            let state = downloadManager.getDownloadState(for: current.video.urlPath)
            inProgress.append(InProgressDownload(video: current.video, state: state))
        }

        // Add queued downloads
        for item in downloadManager.downloadQueue {
            let state = downloadManager.getDownloadState(for: item.video.urlPath)
            inProgress.append(InProgressDownload(video: item.video, state: state))
        }

        inProgressDownloads = inProgress
    }
}
