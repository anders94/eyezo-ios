import Foundation

@MainActor
class WatchProgressReporter {
    static let shared = WatchProgressReporter()

    private var isRequestInFlight = false
    private var pendingRequest: PendingRequest?

    private struct PendingRequest {
        let serverURL: URL
        let videoPath: String
        let position: Double
    }

    private init() {}

    func reportProgress(serverURL: URL, videoPath: String, position: Double) {
        // If a request is in flight, queue this one (replacing any existing queued request)
        if isRequestInFlight {
            pendingRequest = PendingRequest(serverURL: serverURL, videoPath: videoPath, position: position)
            return
        }

        // Send the request immediately
        Task {
            await sendRequest(serverURL: serverURL, videoPath: videoPath, position: position)
        }
    }

    private func sendRequest(serverURL: URL, videoPath: String, position: Double) async {
        isRequestInFlight = true

        let url = serverURL.appendingPathComponent("api/watch-progress")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "path": videoPath,
            "position": position
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Send request (fire and forget - don't handle errors)
        _ = try? await URLSession.shared.data(for: request)

        // Request completed
        isRequestInFlight = false

        // Process pending request if one exists
        if let pending = pendingRequest {
            pendingRequest = nil
            await sendRequest(serverURL: pending.serverURL, videoPath: pending.videoPath, position: pending.position)
        }
    }
}
