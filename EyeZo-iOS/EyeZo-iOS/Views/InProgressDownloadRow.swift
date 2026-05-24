import SwiftUI

struct InProgressDownloadRow: View {
    let download: InProgressDownload

    var body: some View {
        HStack(spacing: 12) {
            // Placeholder thumbnail (grayed out)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 56)

                // Download status icon
                switch download.state {
                case .downloading(let progress):
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 36, height: 36)

                        if progress == 0.5 {
                            // Indeterminate progress
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            // Known progress
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 36, height: 36)
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(progress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }

                case .queued:
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.title2)

                default:
                    ProgressView()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(download.video.name)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    Text(download.video.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Status text
                    switch download.state {
                    case .downloading:
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    case .queued:
                        Text("Waiting...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
