import SwiftUI

/// Red bar along the bottom of a thumbnail showing how much has been watched
struct WatchProgressBar: View {
    /// 0-100
    let percentage: Double

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: geometry.size.width * (percentage / 100))

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
