import Foundation

/// A video that is queued, downloading, or failed - shown in the Downloads
/// tree where it will live once finished
struct PendingDownload {
    let video: VideoItem
    let serverURL: URL
    let state: DownloadState
    let queuePosition: Int?
}

enum DownloadEntry: Identifiable {
    case downloaded(DownloadedVideo)
    case pending(PendingDownload)

    var urlPath: String {
        switch self {
        case .downloaded(let video): return video.urlPath
        case .pending(let download): return download.video.urlPath
        }
    }

    var name: String {
        switch self {
        case .downloaded(let video): return video.videoName
        case .pending(let download): return download.video.name
        }
    }

    var size: Int64 {
        switch self {
        case .downloaded(let video): return video.fileSize
        case .pending(let download): return download.video.size
        }
    }

    var isPending: Bool {
        if case .pending = self { return true }
        return false
    }

    var id: String { urlPath }

    var folder: [String] { DownloadTree.folder(forURLPath: urlPath) }
}

/// A folder in the Downloads tree, derived from the server paths of the
/// videos inside it
struct DownloadFolder: Identifiable {
    let path: [String]
    let videoCount: Int
    let pendingCount: Int
    let downloadedCount: Int
    let totalSize: Int64
    /// Bytes actually on disk, i.e. what deleting the folder frees up
    let downloadedSize: Int64

    var name: String { path.last ?? "" }
    var id: [String] { path }
}

enum DownloadTree {
    /// The decoded path components of a server urlPath, e.g.
    /// "Movies/My%20Video.mp4" -> ["Movies", "My Video.mp4"]
    static func components(forURLPath urlPath: String) -> [String] {
        urlPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { segment in
                let segment = String(segment)
                return segment.removingPercentEncoding ?? segment
            }
    }

    /// The folder a video lives in, e.g. "Movies/Video.mp4" -> ["Movies"]
    static func folder(forURLPath urlPath: String) -> [String] {
        Array(components(forURLPath: urlPath).dropLast())
    }

    static func isEntry(_ entry: DownloadEntry, inFolder folder: [String]) -> Bool {
        entry.folder.starts(with: folder)
    }

    static func urlPath(_ urlPath: String, isInFolder folder: [String]) -> Bool {
        self.folder(forURLPath: urlPath).starts(with: folder)
    }

    static func folderExists(_ folder: [String], in entries: [DownloadEntry]) -> Bool {
        entries.contains { isEntry($0, inFolder: folder) }
    }

    /// The immediate subfolders and videos of `folder`, each sorted by name
    static func contents(at folder: [String], entries: [DownloadEntry]) -> (folders: [DownloadFolder], videos: [DownloadEntry]) {
        var videos: [DownloadEntry] = []
        var subfolderEntries: [String: [DownloadEntry]] = [:]

        for entry in entries {
            let entryFolder = entry.folder
            guard entryFolder.starts(with: folder) else { continue }

            if entryFolder.count == folder.count {
                videos.append(entry)
            } else {
                subfolderEntries[entryFolder[folder.count], default: []].append(entry)
            }
        }

        let folders = subfolderEntries.map { name, entries in
            let pendingCount = entries.filter(\.isPending).count
            return DownloadFolder(
                path: folder + [name],
                videoCount: entries.count,
                pendingCount: pendingCount,
                downloadedCount: entries.count - pendingCount,
                totalSize: entries.reduce(0) { $0 + $1.size },
                downloadedSize: entries.filter { !$0.isPending }.reduce(0) { $0 + $1.size }
            )
        }

        return (
            folders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            videos.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        )
    }
}

extension Int64 {
    /// Human-readable byte count, e.g. "1.2 GB"
    var formattedByteCount: String {
        let bytes = Double(self)
        let kb = bytes / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }
}
