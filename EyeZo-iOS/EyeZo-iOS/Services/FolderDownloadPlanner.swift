import Foundation

/// Everything under a server folder that still needs downloading
struct FolderDownloadPlan: Identifiable {
    let id = UUID()
    let folderName: String
    let serverURL: URL
    let videos: [VideoItem]

    var totalSize: Int64 {
        videos.reduce(0) { $0 + $1.size }
    }

    /// Free space on the device, if it can be determined
    var availableCapacity: Int64? {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        return (try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage
    }

    var exceedsAvailableCapacity: Bool {
        guard let availableCapacity = availableCapacity else { return false }
        return totalSize > availableCapacity
    }
}

/// Walks a server folder recursively to find every video under it.
/// The server has no recursive listing, so this browses each subfolder in turn.
@MainActor
struct FolderDownloadPlanner {
    private let apiService = APIService()
    private let downloadManager = DownloadManager.shared

    /// - Parameter path: the folder's urlPath, or nil for the server root
    func plan(serverURL: URL, path: String?, folderName: String) async throws -> FolderDownloadPlan {
        var videos: [VideoItem] = []
        var foldersToVisit: [String?] = [path]

        while !foldersToVisit.isEmpty {
            let folder = foldersToVisit.removeFirst()
            let response = try await apiService.browse(serverURL: serverURL, path: folder)

            // Skip hidden files, matching what the browser shows
            videos += response.videos.filter { !$0.name.hasPrefix(".") }
            foldersToVisit += response.directories
                .filter { !$0.name.hasPrefix(".") }
                .map(\.urlPath)
        }

        let remaining = videos.filter { video in
            switch downloadManager.getDownloadState(for: video.urlPath) {
            case .completed, .alreadyDownloaded, .queued, .downloading:
                return false
            case .none, .failed:
                return true
            }
        }

        return FolderDownloadPlan(folderName: folderName, serverURL: serverURL, videos: remaining)
    }
}
