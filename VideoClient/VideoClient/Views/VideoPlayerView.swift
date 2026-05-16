import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: UIViewControllerRepresentable {
    let video: VideoItem
    let serverURL: URL?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Configure audio session
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let controller = AVPlayerViewController()

        guard let serverURL = serverURL else { return controller }

        let apiService = APIService()
        let videoURL = apiService.getVideoURL(serverURL: serverURL, videoPath: video.urlPath)

        let player = AVPlayer(url: videoURL)
        controller.player = player

        // Auto-play
        player.play()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(
            video: VideoItem(
                name: "Sample.mp4",
                path: "/path/to/Sample.mp4",
                relativePath: "videos/Sample.mp4",
                urlPath: "videos/Sample.mp4",
                size: 1024000,
                modified: Date().timeIntervalSince1970,
                extension: ".mp4",
                mimeType: "video/mp4",
                thumbnailUrl: "/api/thumbnail/videos/Sample.mp4"
            ),
            serverURL: URL(string: "http://127.0.0.1:3000")
        )
    }
}
