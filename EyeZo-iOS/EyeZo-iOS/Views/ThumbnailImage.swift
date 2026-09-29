import SwiftUI

/// A 16:9 thumbnail that fills its box and crops the overflow.
/// The image is drawn as an overlay so its own aspect ratio can never
/// affect layout — very wide or very tall videos stay within the tile.
struct ThumbnailImage: View {
    let image: Image

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                image
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .cornerRadius(12)
            // Keep taps from landing on the cropped-away parts of the image
            .contentShape(Rectangle())
    }
}
