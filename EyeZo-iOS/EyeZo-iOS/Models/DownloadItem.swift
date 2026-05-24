import Foundation

struct DownloadItem: Identifiable {
    let id: UUID
    let video: VideoItem
    let serverURL: URL
    var state: DownloadState
    var downloadTask: URLSessionDownloadTask?

    init(video: VideoItem, serverURL: URL) {
        self.id = UUID()
        self.video = video
        self.serverURL = serverURL
        self.state = .queued
        self.downloadTask = nil
    }
}
