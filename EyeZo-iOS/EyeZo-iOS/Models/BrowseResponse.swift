import Foundation

struct BrowseResponse: Codable {
    let path: String
    let parent: String?
    let directories: [DirectoryItem]
    let videos: [VideoItem]
    let totalDirectories: Int
    let totalVideos: Int
}
