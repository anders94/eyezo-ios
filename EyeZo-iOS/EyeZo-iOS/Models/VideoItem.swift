import Foundation

struct VideoItem: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let relativePath: String
    let urlPath: String
    let size: Int64
    let modified: TimeInterval
    let `extension`: String
    let mimeType: String
    let thumbnailUrl: String?
    let duration: Double?
    let watchPosition: Double?
    let lastWatched: Int?

    var id: String { urlPath }

    var hasThumbnail: Bool {
        thumbnailUrl != nil
    }

    var watchPercentage: Double {
        guard let duration = duration, duration > 0,
              let position = watchPosition, position > 0 else { return 0 }
        return min((position / duration) * 100, 100)
    }

    var formattedSize: String {
        size.formattedByteCount
    }
}
