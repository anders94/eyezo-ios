import SwiftUI
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure the audio session once, before anything activates it.
        // AVPlayer activates it itself when playback starts.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        return true
    }

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
        }
    }
}
