import SwiftUI

struct DirectoryBrowserView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @StateObject private var serverURLManager = ServerURLManager.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var selectedVideo: VideoItem?
    // urlPath of the folder being sized for download
    @State private var scanningFolderPath: String?
    // Edit mode shows download buttons on every tile
    @State private var isEditing = false
    @State private var folderPlan: FolderDownloadPlan?
    @State private var folderScanError: String?
    var onBack: (() -> Void)? = nil

    private var displayTitle: String {
        guard let path = viewModel.currentPath else {
            // At root - show server URL
            return serverDisplayName
        }
        // Extract just the last component of the path for display
        let components = path.split(separator: "/")
        let lastComponent = components.last.map(String.init) ?? serverDisplayName
        // Decode URL encoding (e.g., %20 -> space)
        return lastComponent.removingPercentEncoding ?? lastComponent
    }

    private var parentDisplayName: String {
        guard let parentPath = viewModel.parentPath else {
            // At root - back button should say "Servers"
            return "Servers"
        }
        // If parent is root (empty or "/"), show server URL
        if parentPath.isEmpty || parentPath == "/" {
            return serverDisplayName
        }
        // Extract the last component of the parent path
        let components = parentPath.split(separator: "/")
        let lastComponent = components.last.map(String.init) ?? serverDisplayName
        // Decode URL encoding
        return lastComponent.removingPercentEncoding ?? lastComponent
    }

    private var serverDisplayName: String {
        guard let serverURL = serverURLManager.serverURL else {
            return "Server"
        }
        // Show host:port if available, otherwise just host
        if let host = serverURL.host {
            if let port = serverURL.port {
                return "\(host):\(port)"
            }
            return host
        }
        // Fallback to full URL
        return serverURL.absoluteString
    }

    var body: some View {
        ZStack {
            Group {
                if let errorMessage = viewModel.errorMessage, viewModel.directories.isEmpty && viewModel.videos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)

                        Text("Error")
                            .font(.title)
                            .fontWeight(.semibold)

                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("Retry") {
                            Task {
                                await viewModel.refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ZStack {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                            ], spacing: 16) {
                                // Directories first
                                ForEach(viewModel.directories) { directory in
                                    ZStack(alignment: .topTrailing) {
                                        Button(action: {
                                            Task {
                                                await viewModel.loadDirectory(directory.urlPath)
                                            }
                                        }) {
                                            DirectoryGridItem(directory: directory)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(viewModel.isLoading)

                                        if isEditing || scanningFolderPath == directory.urlPath {
                                            DownloadButton(isBusy: scanningFolderPath == directory.urlPath) {
                                                planFolderDownload(path: directory.urlPath, name: directory.name)
                                            }
                                            .padding(8)
                                            .disabled(scanningFolderPath != nil)
                                        }
                                    }
                                }

                                // Videos
                                ForEach(viewModel.videos) { video in
                                    VideoGridItem(video: video, serverURL: serverURLManager.serverURL, isEditing: isEditing)
                                        .onTapGesture {
                                            if !viewModel.isLoading {
                                                selectedVideo = video
                                            }
                                        }
                                }
                            }
                            .padding()

                            // Empty state
                            if viewModel.directories.isEmpty && viewModel.videos.isEmpty && !viewModel.isLoading {
                                VStack(spacing: 16) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("No videos or directories found")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                            }
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                        .opacity(viewModel.isLoading && !viewModel.directories.isEmpty ? 0.5 : 1.0)

                        // Show loading overlay when navigating with existing data
                        if viewModel.isLoading && !viewModel.directories.isEmpty {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        }
                    }
                }
            }

            // Initial loading overlay - shown when no data loaded yet
            if viewModel.isLoading && viewModel.directories.isEmpty && viewModel.videos.isEmpty && viewModel.errorMessage == nil {
                Color(UIColor.systemBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .overlay(
                        ProgressView("Loading...")
                    )
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.parentPath != nil {
                        // In a subdirectory - show back to parent button
                        Button(action: {
                            Task {
                                await viewModel.loadDirectory(viewModel.parentPath)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(parentDisplayName)
                            }
                        }
                    } else if let onBack = onBack {
                        // At root - show back button as "Servers"
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Servers")
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    // Filled while active
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Image(systemName: isEditing ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    .accessibilityLabel(isEditing ? "Done" : "Download")
                }
            }
            .fullScreenCover(item: $selectedVideo, onDismiss: {
                // Refresh to show updated watch progress
                // Small delay to let server process the final progress update
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await viewModel.refresh()
                }
            }) { video in
                VideoPlayerView(video: video, serverURL: serverURLManager.serverURL)
                    .ignoresSafeArea()
            }
            .alert(
                folderPlan?.videos.isEmpty == true ? "Already Downloaded" : "Download Folder",
                isPresented: Binding(
                    get: { folderPlan != nil },
                    set: { if !$0 { folderPlan = nil } }
                ),
                presenting: folderPlan
            ) { plan in
                if plan.videos.isEmpty {
                    Button("OK", role: .cancel) { }
                } else {
                    Button("Cancel", role: .cancel) { }
                    Button("Download") {
                        downloadManager.addToDownloadQueue(videos: plan.videos, serverURL: plan.serverURL)
                    }
                }
            } message: { plan in
                Text(folderPlanMessage(plan))
            }
            .alert("Couldn't Read Folder", isPresented: Binding(
                get: { folderScanError != nil },
                set: { if !$0 { folderScanError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(folderScanError ?? "")
            }
            .onAppear {
            // Load root directory on first appearance
            // Use detached task to ensure it doesn't block tab switching
            if !viewModel.hasAttemptedInitialLoad && viewModel.currentPath == nil {
                let vm = viewModel
                Task.detached(priority: .userInitiated) { @MainActor in
                    // Small delay to ensure view is fully rendered
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await vm.loadDirectory(nil)
                }
            }
        }
    }

    /// Totals up everything under a folder, then asks before downloading it
    private func planFolderDownload(path: String, name: String) {
        guard let serverURL = serverURLManager.serverURL, scanningFolderPath == nil else { return }

        scanningFolderPath = path
        Task {
            do {
                folderPlan = try await FolderDownloadPlanner().plan(serverURL: serverURL, path: path, folderName: name)
            } catch {
                folderScanError = error.localizedDescription
            }
            scanningFolderPath = nil
        }
    }

    private func folderPlanMessage(_ plan: FolderDownloadPlan) -> String {
        guard !plan.videos.isEmpty else {
            return "Everything in '\(plan.folderName)' is already downloaded or queued."
        }

        let count = plan.videos.count
        var message = "Are you sure you want to download \(plan.totalSize.formattedByteCount)? "
            + "'\(plan.folderName)' has \(count) \(count == 1 ? "video" : "videos") that \(count == 1 ? "isn't" : "aren't") downloaded yet."

        if plan.exceedsAvailableCapacity, let available = plan.availableCapacity {
            message += "\n\nOnly \(available.formattedByteCount) of storage is available on this device."
        }

        return message
    }
}

struct DirectoryGridItem: View {
    let directory: DirectoryItem

    var body: some View {
        VStack(spacing: 8) {
            // Folder icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)

                Image(systemName: "folder.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }

            // Directory name
            Text(directory.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

struct VideoGridItem: View {
    let video: VideoItem
    let serverURL: URL?
    var isEditing = false
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var showErrorAlert = false
    @State private var showCancelAlert = false
    @State private var errorMessage = ""

    private var thumbnailURL: URL? {
        guard let serverURL = serverURL,
              video.hasThumbnail else { return nil }
        let apiService = APIService()
        return apiService.getThumbnailURL(serverURL: serverURL, videoPath: video.urlPath)
    }

    private var downloadState: DownloadState {
        downloadManager.getDownloadState(for: video.urlPath)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail with progress bar and download status
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                if let thumbnailURL = thumbnailURL {
                    CachedAsyncImageWithPhase(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(16/9, contentMode: .fit)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        case .success(let image):
                            ThumbnailImage(image: image)
                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(16/9, contentMode: .fit)

                                Image(systemName: "film.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)

                        Image(systemName: "film.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }

                    // Download button (in edit mode), or the status of an existing download
                    if downloadState == .none {
                        if isEditing {
                            DownloadButton {
                                if let serverURL = serverURL {
                                    downloadManager.addToDownloadQueue(video: video, serverURL: serverURL)
                                }
                            }
                            .padding(8)
                        }
                    } else {
                        DownloadStatusBadge(
                            state: downloadState,
                            queuePosition: downloadManager.queuePosition(for: video.urlPath)
                        )
                        .padding(8)
                        .onTapGesture {
                            switch downloadState {
                            case .failed(let error):
                                errorMessage = error
                                showErrorAlert = true
                            case .queued, .downloading:
                                showCancelAlert = true
                            default:
                                break
                            }
                        }
                    }
                }

                // Watch progress bar
                if video.watchPercentage > 0 {
                    WatchProgressBar(percentage: video.watchPercentage)
                }
            }

            // Video name
            Text(video.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // File size
            Text(video.formattedSize)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .alert("Download Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
            Button("Retry") {
                if let serverURL = serverURL {
                    downloadManager.addToDownloadQueue(video: video, serverURL: serverURL)
                }
            }
        } message: {
            Text(errorMessage)
        }
        .alert("Cancel Download", isPresented: $showCancelAlert) {
            Button("Keep Downloading", role: .cancel) { }
            Button("Cancel Download", role: .destructive) {
                downloadManager.cancelDownload(for: video.urlPath)
            }
        } message: {
            Text("Cancel download of '\(video.name)'?")
        }
    }
}

struct DirectoryBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        DirectoryBrowserView()
    }
}
