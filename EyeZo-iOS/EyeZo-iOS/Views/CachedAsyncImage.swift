import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        // Start with a cached image if there is one, so it's drawn on the first frame
        _loadedImage = State(initialValue: url.flatMap { ImageCache.shared.cachedImage(for: $0) })
    }

    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                content(Image(uiImage: loadedImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url = url else { return }
            loadedImage = await ImageCache.shared.image(for: url)
        }
    }
}

// Convenience initializer matching AsyncImage API
extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.init(url: url, content: { $0.resizable() }, placeholder: { Color.gray.opacity(0.2) })
    }
}

// Phase-based initializer similar to AsyncImage
struct CachedAsyncImagePhase {
    enum LoadingPhase {
        case empty
        case success(Image)
        case failure
    }

    let phase: LoadingPhase
}

struct CachedAsyncImageWithPhase<Content: View>: View {
    let url: URL?
    let content: (CachedAsyncImagePhase.LoadingPhase) -> Content

    @State private var loadedImage: UIImage?
    @State private var hasFailed = false

    init(url: URL?, @ViewBuilder content: @escaping (CachedAsyncImagePhase.LoadingPhase) -> Content) {
        self.url = url
        self.content = content
        // Start with a cached image if there is one, so it's drawn on the first frame
        _loadedImage = State(initialValue: url.flatMap { ImageCache.shared.cachedImage(for: $0) })
    }

    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                content(.success(Image(uiImage: loadedImage)))
            } else if hasFailed {
                content(.failure)
            } else {
                content(.empty)
            }
        }
        .task(id: url) {
            guard let url = url else {
                hasFailed = true
                return
            }

            hasFailed = false

            if let image = await ImageCache.shared.image(for: url) {
                loadedImage = image
            } else {
                hasFailed = true
            }
        }
    }
}
