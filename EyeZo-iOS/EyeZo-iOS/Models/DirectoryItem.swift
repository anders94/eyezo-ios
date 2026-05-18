import Foundation

struct DirectoryItem: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let relativePath: String
    let urlPath: String
    let modified: TimeInterval

    var id: String { urlPath }
}
