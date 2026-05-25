import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case networkFailure(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkFailure(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

class APIService {
    // Custom URLSession with shorter timeouts for better responsiveness
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10  // 10 seconds for request timeout
        config.timeoutIntervalForResource = 15  // 15 seconds for resource timeout
        return URLSession(configuration: config)
    }()

    func checkHealth(serverURL: URL) async throws -> Bool {
        let healthURL = serverURL.appendingPathComponent("api/health")

        do {
            let (_, response) = try await urlSession.data(from: healthURL)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            throw NetworkError.networkFailure(error)
        }
    }

    func browse(serverURL: URL, path: String? = nil) async throws -> BrowseResponse {
        var browseURL: URL
        if let path = path, !path.isEmpty {
            browseURL = serverURL
                .appendingPathComponent("api/browse")
                .appendingPathComponent(path)
        } else {
            browseURL = serverURL.appendingPathComponent("api/browse")
        }

        do {
            let (data, response) = try await urlSession.data(from: browseURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            do {
                let decoder = JSONDecoder()
                let browseResponse = try decoder.decode(BrowseResponse.self, from: data)
                return browseResponse
            } catch {
                throw NetworkError.decodingError(error)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkFailure(error)
        }
    }

    func getVideoURL(serverURL: URL, videoPath: String) -> URL {
        // videoPath is already URL-encoded from the server
        // We need to construct the URL carefully to avoid double-encoding
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = "/api/video/\(videoPath)"
        return components.url!
    }

    func getThumbnailURL(serverURL: URL, videoPath: String) -> URL? {
        // videoPath is already URL-encoded from the server
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = "/api/thumbnail/\(videoPath)"
        return components.url
    }

    func reportWatchProgress(serverURL: URL, videoPath: String, position: Double) {
        // Use the shared reporter to ensure only one request at a time
        Task { @MainActor in
            WatchProgressReporter.shared.reportProgress(serverURL: serverURL, videoPath: videoPath, position: position)
        }
    }
}
