import SwiftUI

struct DownloadStatusBadge: View {
    let state: DownloadState
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
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 32, height: 32)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
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
