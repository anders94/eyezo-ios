import UIKit
import SwiftUI

actor ImageCache {
    static let shared = ImageCache()

    // NSCache is thread-safe, which lets views check it synchronously
    // (see cachedImage(for:)) without hopping onto the actor
    private nonisolated(unsafe) let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB of decoded pixels
        return cache
    }()

    private var pendingRequests: [URL: Task<UIImage?, Never>] = [:]

    private init() {}

    /// An already-loaded image, available immediately so a tile that scrolls
    /// back into view can draw it on its first frame
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Loads an image from a server or a local file URL
    func image(for url: URL) async -> UIImage? {
        // Check if image is already cached
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        // Check if there's already a pending request for this URL
        if let pendingTask = pendingRequests[url] {
            return await pendingTask.value
        }

        // Fetch and decode off the actor so loads run in parallel
        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = await Self.loadData(from: url),
                  let image = UIImage(data: data) else { return nil }

            // Decode now, in the background, instead of on the main thread at first draw
            return await image.byPreparingForDisplay() ?? image
        }

        pendingRequests[url] = task
        let image = await task.value
        pendingRequests[url] = nil

        if let image = image {
            cache.setObject(image, forKey: url as NSURL, cost: Self.decodedSize(of: image))
        }
        return image
    }

    private static func loadData(from url: URL) async -> Data? {
        if url.isFileURL {
            return try? Data(contentsOf: url)
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }
        return data
    }

    private static func decodedSize(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    func clearCache() {
        cache.removeAllObjects()
        pendingRequests.removeAll()
    }
}
