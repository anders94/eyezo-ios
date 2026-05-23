import UIKit
import SwiftUI

actor ImageCache {
    static let shared = ImageCache()

    private var cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 100 // Store up to 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        return cache
    }()

    private var pendingRequests: [URL: Task<UIImage?, Never>] = [:]

    private init() {}

    func image(for url: URL) async -> UIImage? {
        // Check if image is already cached
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        // Check if there's already a pending request for this URL
        if let pendingTask = pendingRequests[url] {
            return await pendingTask.value
        }

        // Create a new download task
        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                // Validate response
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let image = UIImage(data: data) else {
                    await removePendingRequest(for: url)
                    return nil
                }

                // Cache the image
                await cacheImage(image, for: url)
                await removePendingRequest(for: url)

                return image
            } catch {
                await removePendingRequest(for: url)
                return nil
            }
        }

        pendingRequests[url] = task
        return await task.value
    }

    private func cacheImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    private func removePendingRequest(for url: URL) {
        pendingRequests[url] = nil
    }

    func clearCache() {
        cache.removeAllObjects()
        pendingRequests.removeAll()
    }
}
