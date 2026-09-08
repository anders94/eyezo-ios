import SwiftUI

struct DownloadedVideoGridItem: View {
    // Observed so the watch progress bar updates after playback
    @ObservedObject var video: DownloadedVideo

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail with watch progress bar
            ZStack(alignment: .bottom) {
                if let thumbnailPath = video.thumbnailPath,
                   let image = UIImage(contentsOfFile: thumbnailPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipped()
                        .cornerRadius(12)
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
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geometry.size.width * (video.watchPercentage / 100))

                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(2)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
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
