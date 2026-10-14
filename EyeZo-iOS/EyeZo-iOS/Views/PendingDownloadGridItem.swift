import SwiftUI

/// A queued, downloading, or failed video, shown where it will live in the Downloads tree
struct PendingDownloadGridItem: View {
    let download: PendingDownload
    var showsBadge = true

    private var thumbnailURL: URL? {
        guard download.video.hasThumbnail else { return nil }
        return APIService().getThumbnailURL(serverURL: download.serverURL, videoPath: download.video.urlPath)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Server thumbnail while reachable, placeholder otherwise
                CachedAsyncImage(url: thumbnailURL) { image in
                    ThumbnailImage(image: image)
                } placeholder: {
                    ThumbnailPlaceholder()
                }
                .opacity(0.6)

                if showsBadge {
                    DownloadStatusBadge(state: download.state, queuePosition: download.queuePosition)
                        .padding(8)
                }
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

                Text("·")
                    .foregroundColor(.secondary)

                switch download.state {
                case .downloading:
                    Text("Downloading…")
                        .foregroundColor(.blue)
                case .failed:
                    Text("Failed")
                        .foregroundColor(.red)
                default:
                    Text("Queued for download")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption2)
        }
    }
}
