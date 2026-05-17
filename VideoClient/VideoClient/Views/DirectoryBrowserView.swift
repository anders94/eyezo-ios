import SwiftUI

struct DirectoryBrowserView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @StateObject private var serverURLManager = ServerURLManager.shared
    @State private var selectedVideo: VideoItem?
    @State private var showingServerSetup = false

    private var displayTitle: String {
        guard let path = viewModel.currentPath else { return "Videos" }
        // Extract just the last component of the path for display
        let components = path.split(separator: "/")
        let lastComponent = components.last.map(String.init) ?? "Videos"
        // Decode URL encoding (e.g., %20 -> space)
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
                                Button(action: {
                                    selectedVideo = video
                                }) {
                                    VideoGridItem(video: video, serverURL: serverURLManager.serverURL)
                                }
                                .buttonStyle(.plain)
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
                                Text("Back")
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
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(video: video, serverURL: serverURLManager.serverURL)
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showingServerSetup) {
                ServerSetupView()
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

    private var thumbnailURL: URL? {
        guard let serverURL = serverURL,
              video.hasThumbnail else { return nil }
        let apiService = APIService()
        return apiService.getThumbnailURL(serverURL: serverURL, videoPath: video.urlPath)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail with progress bar
            ZStack(alignment: .bottom) {
                if let thumbnailURL = thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
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
                        @unknown default:
                            EmptyView()
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
    }
}

struct DirectoryBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        DirectoryBrowserView()
    }
}
