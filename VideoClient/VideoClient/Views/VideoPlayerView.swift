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

        // Set up progress tracking
        let coordinator = context.coordinator
        coordinator.serverURL = serverURL
        coordinator.videoPath = video.urlPath
        coordinator.player = player
        coordinator.controller = controller

        // Resume from last position if available
        if let duration = video.duration, let watchPosition = video.watchPosition,
           watchPosition > 0, watchPosition < duration * 0.95 {
            let time = CMTime(seconds: watchPosition, preferredTimescale: 1)
            player.seek(to: time)
        }

        // Set up periodic time observer (every 10 seconds)
        let interval = CMTime(seconds: 10, preferredTimescale: 1)
        let timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            coordinator.reportProgress(position: time.seconds)
        }
        coordinator.timeObserver = timeObserver

        // Auto-play
        player.play()

        return controller
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var serverURL: URL?
        var videoPath: String?
        var player: AVPlayer?
        var controller: AVPlayerViewController?
        var timeObserver: Any?
        private var hasCleanedUp = false

        func reportProgress(position: Double) {
            guard let serverURL = serverURL, let videoPath = videoPath else { return }

            let apiService = APIService()
            apiService.reportWatchProgress(serverURL: serverURL, videoPath: videoPath, position: position)
        }

        func cleanup() {
            guard !hasCleanedUp else { return }

            hasCleanedUp = true

            // Pause the player immediately
            player?.pause()

            // Report final position
            if let player = player {
                let position = player.currentTime().seconds
                reportProgress(position: position)
            }

            // Remove time observer
            if let timeObserver = timeObserver, let player = player {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }

            // Clear player reference
            controller?.player = nil
            player = nil
            controller = nil
        }

        deinit {
            cleanup()
        }
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
                thumbnailUrl: "/api/thumbnail/videos/Sample.mp4",
                duration: 3600,
                watchPosition: 1800,
                lastWatched: 1778985835
            ),
            serverURL: URL(string: "http://127.0.0.1:3000")
        )
    }
}
