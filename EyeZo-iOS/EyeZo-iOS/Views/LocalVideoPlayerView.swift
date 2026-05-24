import SwiftUI
import AVKit
import AVFoundation

struct LocalVideoPlayerView: UIViewControllerRepresentable {
    let video: DownloadedVideo

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Configure audio session
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let controller = AVPlayerViewController()

        let fileURL = URL(fileURLWithPath: video.localFilePath)
        let player = AVPlayer(url: fileURL)
        controller.player = player

        context.coordinator.player = player
        context.coordinator.controller = controller

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
        var player: AVPlayer?
        var controller: AVPlayerViewController?
        private var hasCleanedUp = false

        func cleanup() {
            guard !hasCleanedUp else { return }

            hasCleanedUp = true

            // Pause the player immediately
            player?.pause()

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
