import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

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

            isLoading = true
            loadedImage = await ImageCache.shared.image(for: url)
            isLoading = false
        }
    }
}

// Convenience initializer matching AsyncImage API
extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.url = url
        self.content = { $0.resizable() }
        self.placeholder = { Color.gray.opacity(0.2) }
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
    @ViewBuilder let content: (CachedAsyncImagePhase.LoadingPhase) -> Content

    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var hasFailed = false

    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                content(.success(Image(uiImage: loadedImage)))
            } else if hasFailed {
                content(.failure)
            } else if isLoading {
                content(.empty)
            }
        }
        .task(id: url) {
            guard let url = url else {
                hasFailed = true
                isLoading = false
                return
            }

            isLoading = true
            hasFailed = false

            if let image = await ImageCache.shared.image(for: url) {
                loadedImage = image
                isLoading = false
            } else {
                hasFailed = true
                isLoading = false
            }
        }
    }
}
