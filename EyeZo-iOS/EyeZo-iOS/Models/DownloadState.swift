import Foundation

enum DownloadState: Equatable {
    case none                           // Not downloaded
    case alreadyDownloaded             // Already exists locally
    case queued                         // In download queue
    case downloading(progress: Double)  // Actively downloading (0.0-1.0)
    case completed                      // Download finished
    case failed(error: String)         // Download failed

    var isDownloadable: Bool {
        switch self {
        case .none, .failed:
            return true
        default:
            return false
        }
    }

    var isInProgress: Bool {
        switch self {
        case .queued, .downloading:
            return true
        default:
            return false
        }
    }
}
