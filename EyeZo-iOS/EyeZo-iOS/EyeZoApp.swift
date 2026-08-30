import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Store completion handler for when downloads finish in background
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }
}

@main
struct EyeZoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.scenePhase) private var scenePhase

    private enum Tab {
        case browse
        case downloads
    }

    @State private var selectedTab: Tab = .browse
    @State private var hasPickedInitialTab = false

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                BrowseTabView()
                    .tabItem {
                        Label("Browse", systemImage: "film.stack")
                    }
                    .tag(Tab.browse)

                DownloadsView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle.fill")
                    }
                    .tag(Tab.downloads)
            }
            .onReceive(networkMonitor.$isConnected) { isConnected in
                // On launch, once we know the network state: if offline,
                // land on Downloads since Browse can't load anything
                guard let isConnected = isConnected, !hasPickedInitialTab else { return }
                hasPickedInitialTab = true
                if !isConnected {
                    selectedTab = .downloads
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, networkMonitor.isConnected == true {
                    Task {
                        await WatchProgressSyncService.shared.syncIfNeeded()
                    }
                }
            }
        }
    }
}
