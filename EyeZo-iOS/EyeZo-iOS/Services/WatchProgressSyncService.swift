import Foundation
import CoreData

/// Reconciles watch progress between locally downloaded videos and the
/// server each video was downloaded from. Newest progress always wins:
/// - local progress newer than the server's -> push it to the server
/// - server progress newer (e.g. the online copy was watched since) -> pull
///   it into the local record so offline resume starts at the right spot
@MainActor
class WatchProgressSyncService {
    static let shared = WatchProgressSyncService()

    private var isSyncing = false

    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    private struct WatchProgressResponse: Codable {
        let path: String
        let position: Double
        let lastWatched: Int
    }

    private init() {}

    func syncIfNeeded() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let context = CoreDataManager.shared.viewContext
        let request = DownloadedVideo.fetchRequest()
        guard let videos = try? context.fetch(request), !videos.isEmpty else { return }

        var didChangeLocal = false

        for video in videos {
            guard !video.isDeleted, video.managedObjectContext != nil,
                  let serverURL = URL(string: video.serverURL) else { continue }

            guard let serverProgress = await fetchServerProgress(serverURL: serverURL, urlPath: video.urlPath) else {
                continue // server unreachable or path unknown; try again next sync
            }

            let localTimestamp = Int(video.lastWatchedDate?.timeIntervalSince1970 ?? 0)

            if localTimestamp > serverProgress.lastWatched, video.watchPosition > 0 {
                await pushProgress(serverURL: serverURL, urlPath: video.urlPath, position: video.watchPosition)
            } else if serverProgress.lastWatched > localTimestamp, serverProgress.position > 0 {
                video.watchPosition = serverProgress.position
                video.lastWatchedDate = Date(timeIntervalSince1970: TimeInterval(serverProgress.lastWatched))
                didChangeLocal = true
            }
        }

        if didChangeLocal {
            CoreDataManager.shared.saveContext()
        }
    }

    private func fetchServerProgress(serverURL: URL, urlPath: String) async -> WatchProgressResponse? {
        // urlPath is already percent-encoded; avoid double-encoding
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else { return nil }
        components.percentEncodedPath = "/api/watch-progress/\(urlPath)"
        guard let url = components.url else { return nil }

        guard let (data, response) = try? await urlSession.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        return try? JSONDecoder().decode(WatchProgressResponse.self, from: data)
    }

    private func pushProgress(serverURL: URL, urlPath: String, position: Double) async {
        let url = serverURL.appendingPathComponent("api/watch-progress")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "path": urlPath,
            "position": position
        ])

        _ = try? await urlSession.data(for: request)
    }
}
