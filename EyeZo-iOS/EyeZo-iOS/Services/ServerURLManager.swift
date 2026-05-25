import Foundation
import Combine

class ServerURLManager: ObservableObject {
    static let shared = ServerURLManager()

    private let userDefaultsKey = "serverURL"

    // Custom URLSession with shorter timeouts
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    @Published var serverURL: URL? {
        didSet {
            if let url = serverURL {
                UserDefaults.standard.set(url.absoluteString, forKey: userDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            }
        }
    }

    private init() {
        if let urlString = UserDefaults.standard.string(forKey: userDefaultsKey),
           let url = URL(string: urlString) {
            self.serverURL = url
        }
    }

    func saveServerURL(_ url: URL) {
        self.serverURL = url
    }

    func clearServerURL() {
        self.serverURL = nil
    }

    func validateServerURL(_ url: URL) async -> Bool {
        let healthURL = url.appendingPathComponent("api/health")

        do {
            let (_, response) = try await urlSession.data(from: healthURL)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}
