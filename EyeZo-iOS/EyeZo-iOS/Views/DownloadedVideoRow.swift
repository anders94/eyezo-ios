import SwiftUI

struct DownloadedVideoRow: View {
    // Observed so the watch progress bar updates after playback
    @ObservedObject var video: DownloadedVideo

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with watch progress bar
            ZStack(alignment: .bottom) {
                if let thumbnailPath = video.thumbnailPath,
                   let image = UIImage(contentsOfFile: thumbnailPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 56)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 56)
                        Image(systemName: "film.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }

                if video.watchPercentage > 0 {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geometry.size.width * (video.watchPercentage / 100))

                            Spacer(minLength: 0)
                        }
                    }
                    .frame(width: 94, height: 3)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(1.5)
                    .padding(.bottom, 3)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(video.videoName)
                    .font(.body)
                    .lineLimit(2)

                HStack {
                    Text(video.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if video.duration > 0 {
                        Text(video.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
