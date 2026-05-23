import SwiftUI

@main
struct EyeZoApp: App {
    @StateObject private var serverURLManager = ServerURLManager.shared
    @State private var isCheckingServer = true
    @State private var serverIsValid = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingServer {
                    // Loading screen while checking server
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Checking server connection...")
                            .foregroundColor(.secondary)
                    }
                } else if serverIsValid {
                    // Server is configured and reachable
                    DirectoryBrowserView()
                } else {
                    // Need to configure server or server is unreachable
                    ServerSetupView()
                }
            }
            .task {
                await checkServerStatus()
            }
            .onChange(of: serverURLManager.serverURL) {
                // Re-check server status when URL changes (e.g., after user configures it)
                Task {
                    await checkServerStatus()
                }
            }
        }
    }

    private func checkServerStatus() async {
        // Check if we have a saved server URL
        guard let serverURL = serverURLManager.serverURL else {
            isCheckingServer = false
            serverIsValid = false
            return
        }

        // Validate the server is reachable
        let isValid = await serverURLManager.validateServerURL(serverURL)

        await MainActor.run {
            isCheckingServer = false
            serverIsValid = isValid
        }
    }
}
