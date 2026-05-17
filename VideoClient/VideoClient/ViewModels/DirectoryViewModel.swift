import Foundation
import Combine

@MainActor
class DirectoryViewModel: ObservableObject {
    @Published var directories: [DirectoryItem] = []
    @Published var videos: [VideoItem] = []
    @Published var currentPath: String?
    @Published var parentPath: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var serverUnreachable = false

    private let apiService = APIService()
    private let serverURLManager = ServerURLManager.shared

    func loadDirectory(_ path: String? = nil) async {
        guard let serverURL = serverURLManager.serverURL else {
            errorMessage = "No server URL configured"
            serverUnreachable = true
            return
        }

        // Clear all error state before starting
        errorMessage = nil
        serverUnreachable = false
        isLoading = true

        do {
            let response = try await apiService.browse(serverURL: serverURL, path: path)
            currentPath = path
            parentPath = response.parent

            // Filter out hidden files (starting with ".")
            directories = response.directories.filter { !$0.name.hasPrefix(".") }
            videos = response.videos.filter { !$0.name.hasPrefix(".") }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false

            // Check if server is unreachable
            do {
                let isHealthy = try await apiService.checkHealth(serverURL: serverURL)
                if !isHealthy {
                    serverUnreachable = true
                }
            } catch {
                serverUnreachable = true
            }
        }
    }

    func refresh() async {
        await loadDirectory(currentPath)
    }
}
