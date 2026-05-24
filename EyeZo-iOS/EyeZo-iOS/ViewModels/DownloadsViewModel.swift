import Foundation
import Combine

@MainActor
class DownloadsViewModel: ObservableObject {
    @Published private(set) var downloadedVideos: [DownloadedVideo] = []
    @Published private(set) var totalStorageUsed: Int64 = 0

    private let downloadManager = DownloadManager.shared

    var formattedTotalSize: String {
        let bytes = Double(totalStorageUsed)
        let gb = bytes / (1024 * 1024 * 1024)
        let mb = bytes / (1024 * 1024)

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    func loadDownloadedVideos() async {
        downloadedVideos = downloadManager.getAllDownloadedVideos()
        totalStorageUsed = downloadManager.getTotalStorageUsed()
    }

    func deleteVideo(_ video: DownloadedVideo) {
        downloadManager.deleteDownloadedVideo(video)

        // Refresh list
        Task {
            await loadDownloadedVideos()
        }
    }
}
