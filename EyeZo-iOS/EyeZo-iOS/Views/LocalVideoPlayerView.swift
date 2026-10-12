import SwiftUI
import AVKit
import AVFoundation
import CoreData

struct LocalVideoPlayerView: UIViewControllerRepresentable {
    let video: DownloadedVideo

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()

        let player = AVPlayer(url: video.localFileURL)
        controller.player = player

        let coordinator = context.coordinator
        coordinator.video = video
        coordinator.player = player
        coordinator.controller = controller

        // Resume from last position if available (skip if essentially finished)
        if video.watchPosition > 0,
           video.duration <= 0 || video.watchPosition < video.duration * 0.95 {
            let time = CMTime(seconds: video.watchPosition, preferredTimescale: 1)
            player.seek(to: time)
        }

        // Track progress locally
        let interval = CMTime(seconds: 10, preferredTimescale: 1)
        let timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            coordinator.recordProgress(position: time.seconds)
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
        var video: DownloadedVideo?
        var player: AVPlayer?
        var controller: AVPlayerViewController?
        var timeObserver: Any?
        private var hasCleanedUp = false

        func recordProgress(position: Double) {
            guard position.isFinite, position > 0, let video = video else { return }

            // The player knows the real duration even when the server didn't
            let playerDuration = player?.currentItem?.duration.seconds ?? 0

            // Defer past the current SwiftUI update pass: this can be called
            // from dismantleUIViewController mid-update, and the row observes
            // this object, so mutating/saving here would publish during a view update
            DispatchQueue.main.async {
                guard !video.isDeleted, video.managedObjectContext != nil else { return }

                video.watchPosition = position
                video.lastWatchedDate = Date()
                if playerDuration.isFinite, playerDuration > 0, abs(playerDuration - video.duration) > 1 {
                    video.duration = playerDuration
                }
                // Offline progress stays on the device; it's never reported to the server
                CoreDataManager.shared.saveContext()
            }
        }

        func cleanup() {
            guard !hasCleanedUp else { return }

            hasCleanedUp = true

            // Pause the player immediately
            player?.pause()

            // Record final position
            if let player = player {
                let position = player.currentTime().seconds
                recordProgress(position: position)
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
