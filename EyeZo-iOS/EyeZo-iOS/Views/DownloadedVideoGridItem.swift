import SwiftUI

struct DownloadedVideoGridItem: View {
    // Observed so the watch progress bar updates after playback
    @ObservedObject var video: DownloadedVideo

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail with watch progress bar
            ZStack(alignment: .bottom) {
                if let thumbnailURL = video.thumbnailURL,
                   let image = UIImage(contentsOfFile: thumbnailURL.path) {
                    ThumbnailImage(image: Image(uiImage: image))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)

                        Image(systemName: "film.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
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
