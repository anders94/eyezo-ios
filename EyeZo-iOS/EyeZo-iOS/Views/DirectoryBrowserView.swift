import SwiftUI

struct DirectoryBrowserView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @StateObject private var serverURLManager = ServerURLManager.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var selectedVideo: VideoItem?
    @State private var showingServerSetup = false
    @State private var videoToDownload: VideoItem?
    @State private var showDownloadAlert = false
    @State private var showAlreadyDownloadedAlert = false
    @State private var showCancelDownloadAlert = false
    @State private var videoToCancel: VideoItem?

    private var displayTitle: String {
        guard let path = viewModel.currentPath else { return "EyeZo" }
        // Extract just the last component of the path for display
        let components = path.split(separator: "/")
        let lastComponent = components.last.map(String.init) ?? "EyeZo"
        // Decode URL encoding (e.g., %20 -> space)
        return lastComponent.removingPercentEncoding ?? lastComponent
    }

    private var parentDisplayName: String {
        guard let parentPath = viewModel.parentPath else { return "EyeZo" }
        // If parent is root (empty or "/"), show "EyeZo"
        if parentPath.isEmpty || parentPath == "/" {
            return "EyeZo"
        }
        // Extract the last component of the parent path
        let components = parentPath.split(separator: "/")
        let lastComponent = components.last.map(String.init) ?? "EyeZo"
        // Decode URL encoding
        return lastComponent.removingPercentEncoding ?? lastComponent
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.directories.isEmpty && viewModel.videos.isEmpty {
                    ProgressView("Loading...")
                } else if let errorMessage = viewModel.errorMessage, viewModel.directories.isEmpty && viewModel.videos.isEmpty {
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
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                        ], spacing: 16) {
                            // Directories first
                            ForEach(viewModel.directories) { directory in
                                Button(action: {
                                    Task {
                                        await viewModel.loadDirectory(directory.urlPath)
                                    }
                                }) {
                                    DirectoryGridItem(directory: directory)
                                }
                                .buttonStyle(.plain)
                            }

                            // Videos
                            ForEach(viewModel.videos) { video in
                                VideoGridItem(video: video, serverURL: serverURLManager.serverURL)
                                    .onTapGesture {
                                        selectedVideo = video
                                    }
                                    .onLongPressGesture {
                                        handleVideoLongPress(video: video)
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
                }
            }
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.parentPath != nil {
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
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if viewModel.serverUnreachable {
                            Button(action: {
                                showingServerSetup = true
                            }) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }

                        Button(action: {
                            showingServerSetup = true
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                        }
                    }
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
            .fullScreenCover(isPresented: $showingServerSetup) {
                ServerSetupView()
            }
            .alert("Download Video", isPresented: $showDownloadAlert, presenting: videoToDownload) { video in
                Button("Cancel", role: .cancel) {
                    videoToDownload = nil
                }
                Button("Download") {
                    if let serverURL = serverURLManager.serverURL {
                        downloadManager.addToDownloadQueue(video: video, serverURL: serverURL)
                    }
                    videoToDownload = nil
                }
            } message: { video in
                Text("Download '\(video.name)'? The video will be available for offline viewing.")
            }
            .alert("Already Downloaded", isPresented: $showAlreadyDownloadedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This video has already been downloaded and is available in the Downloads tab.")
            }
            .alert("Cancel Download", isPresented: $showCancelDownloadAlert, presenting: videoToCancel) { video in
                Button("Keep Downloading", role: .cancel) {
                    videoToCancel = nil
                }
                Button("Cancel Download", role: .destructive) {
                    downloadManager.cancelDownload(for: video.urlPath)
                    videoToCancel = nil
                }
            } message: { video in
                Text("Cancel download of '\(video.name)'?")
            }
        }
        .navigationViewStyle(.stack)
        .task {
            // Load root directory on first appearance
            if viewModel.currentPath == nil && viewModel.directories.isEmpty && viewModel.videos.isEmpty {
                await viewModel.loadDirectory(nil)
            }
        }
    }

    private func handleVideoLongPress(video: VideoItem) {
        let downloadState = downloadManager.getDownloadState(for: video.urlPath)

        switch downloadState {
        case .none, .failed:
            // Show download confirmation
            videoToDownload = video
            showDownloadAlert = true

        case .alreadyDownloaded, .completed:
            // Show "already downloaded" alert
            showAlreadyDownloadedAlert = true

        case .queued, .downloading:
            // Show cancel download option
            videoToCancel = video
            showCancelDownloadAlert = true
        }
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
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var showErrorAlert = false
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
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(16/9, contentMode: .fit)
                                .clipped()
                                .cornerRadius(12)
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

                    // Download status badge
                    DownloadStatusBadge(state: downloadState)
                        .padding(8)
                        .onTapGesture {
                            if case .failed(let error) = downloadState {
                                errorMessage = error
                                showErrorAlert = true
                            }
                        }
                }

                // Watch progress bar
                if video.watchPercentage > 0 {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geometry.size.width * (video.watchPercentage / 100))

                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(2)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
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
    }
}

struct DirectoryBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        DirectoryBrowserView()
    }
}
