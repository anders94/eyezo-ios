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

    var body: some Scene {
        WindowGroup {
            TabView {
                BrowseTabView()
                    .tabItem {
                        Label("Browse", systemImage: "film.stack")
                    }

                DownloadsView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle.fill")
                    }
            }
        }
    }
}
