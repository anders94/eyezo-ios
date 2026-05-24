import SwiftUI

struct DownloadedVideoRow: View {
    let video: DownloadedVideo

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
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
