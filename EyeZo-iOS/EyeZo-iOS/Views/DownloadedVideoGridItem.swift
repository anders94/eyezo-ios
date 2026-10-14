import SwiftUI

struct DownloadedVideoGridItem: View {
    // Observed so the watch progress bar updates after playback
    @ObservedObject var video: DownloadedVideo

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail with watch progress bar
            ZStack(alignment: .bottom) {
                // Loaded through the cache so scrolling doesn't re-read files from disk
                CachedAsyncImage(url: video.thumbnailURL) { image in
                    ThumbnailImage(image: image)
                } placeholder: {
                    ThumbnailPlaceholder()
                }

                // Watch progress bar
                if video.watchPercentage > 0 {
                    WatchProgressBar(percentage: video.watchPercentage)
                }
            }

            // Video name
            Text(video.videoName)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // File size and duration
            HStack(spacing: 6) {
                Text(video.formattedSize)
                if video.duration > 0 {
                    Text("·")
                    Text(video.formattedDuration)
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
}
