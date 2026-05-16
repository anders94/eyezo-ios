import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: VideoItem
    let serverURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading video...")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
            }

            // Dismiss button in top-left corner
            VStack {
                HStack {
                    Button(action: {
                        player?.pause()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()

                    Spacer()
                }

                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        guard let serverURL = serverURL else { return }

        let apiService = APIService()
        let videoURL = apiService.getVideoURL(serverURL: serverURL, videoPath: video.urlPath)

        let player = AVPlayer(url: videoURL)
        self.player = player

        // Auto-play
        player.play()
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
