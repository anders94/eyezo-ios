import SwiftUI

struct DownloadStatusBadge: View {
    let state: DownloadState
    var queuePosition: Int? = nil
    @State private var isAnimating = false

    var body: some View {
        Group {
            switch state {
            case .none:
                EmptyView()

            case .alreadyDownloaded, .completed:
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }

            case .queued:
                if let queuePosition = queuePosition {
                    // Queued, with its place in line
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)

                        Text("\(queuePosition)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 32)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 32, height: 32)

                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                }

            case .downloading(let progress):
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 44, height: 44)

                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 36, height: 36)

                    // Show indeterminate spinner if progress is 0.5 (server didn't send size)
                    // Otherwise show progress ring
                    if progress == 0.5 {
                        // Indeterminate progress - spinning circle
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .onAppear {
                                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                    isAnimating = true
                                }
                            }
                    } else {
                        // Known size - show percentage
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.3), value: progress)

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

            case .failed:
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 32, height: 32)

                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
            }
        }
    }
}

/// Corner button that starts a download, or a spinner while one is being prepared
struct DownloadButton: View {
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 32, height: 32)

                if isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("Download")
    }
}

/// Corner button shown in edit mode to delete a download
struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 32, height: 32)

                Image(systemName: "trash.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.red)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
    }
}
