import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    // Open folders, each as its path of folder names from the root
    @State private var path: [[String]] = []
    // Shared across folder levels so edit mode stays on while navigating
    @State private var isEditing = false

    var body: some View {
        NavigationStack(path: $path) {
            DownloadsFolderView(folder: [], viewModel: viewModel, isEditing: $isEditing)
                .navigationDestination(for: [String].self) { folder in
                    DownloadsFolderView(folder: folder, viewModel: viewModel, isEditing: $isEditing)
                }
        }
        .task {
            await viewModel.loadDownloadedVideos()
        }
        .onChange(of: viewModel.entries.map(\.id)) {
            // Folders disappear once everything in them is deleted;
            // pop back to the deepest folder that still exists
            if let firstMissing = path.firstIndex(where: { !DownloadTree.folderExists($0, in: viewModel.entries) }) {
                path.removeSubrange(firstMissing...)
            }
            if viewModel.entries.isEmpty {
                isEditing = false
            }
        }
    }
}
