import SwiftUI

struct InProgressDownloadGridItem: View {
    let download: InProgressDownload

    var body: some View {
        VStack(spacing: 8) {
            // Placeholder thumbnail with download status
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)

                Image(systemName: "film.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.4))

                DownloadStatusBadge(state: download.state)
            }

            // Video name
            Text(download.video.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // File size and status
            HStack(spacing: 6) {
                Text(download.video.formattedSize)
                    .foregroundColor(.secondary)

                switch download.state {
                case .downloading:
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("Downloading…")
                        .foregroundColor(.blue)
                case .queued:
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("Waiting…")
                        .foregroundColor(.orange)
                default:
                    EmptyView()
                }
            }
            .font(.caption2)
        }
    }
}
