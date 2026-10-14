import SwiftUI

/// The fixed 16:9 box every thumbnail state is drawn in. Loading, placeholder
/// and loaded states all share it, so a tile never changes size when its
/// image arrives - content is drawn as an overlay and can't affect layout.
struct ThumbnailFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                content()
            }
            .clipped()
            .cornerRadius(12)
            // Keep taps from landing on the cropped-away parts of the image
            .contentShape(Rectangle())
    }
}

/// A 16:9 thumbnail that fills its box and crops the overflow, so very
/// wide or very tall videos stay within the tile.
struct ThumbnailImage: View {
    let image: Image

    var body: some View {
        ThumbnailFrame {
            image
                .resizable()
                .scaledToFill()
        }
    }
}

/// Grey stand-in for a thumbnail that's loading or unavailable
struct ThumbnailPlaceholder: View {
    var isLoading = false

    var body: some View {
        ThumbnailFrame {
            ZStack {
                Color.gray.opacity(0.2)

                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "film.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
