import SwiftUI

struct BrowseTabView: View {
    @StateObject private var serverURLManager = ServerURLManager.shared
    @State private var showDirectoryBrowser = false

    var body: some View {
        NavigationStack {
            if showDirectoryBrowser && serverURLManager.serverURL != nil {
                DirectoryBrowserView(onBack: {
                    showDirectoryBrowser = false
                })
            } else {
                ServerSetupView(onConnect: {
                    showDirectoryBrowser = true
                })
            }
        }
        .onAppear {
            // If we have a saved server URL, automatically navigate to browser
            if serverURLManager.serverURL != nil {
                showDirectoryBrowser = true
            }
        }
    }
}
