import SwiftUI

struct DirectoryBrowserView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @StateObject private var serverURLManager = ServerURLManager.shared
    @State private var selectedVideo: VideoItem?
    @State private var showingServerSetup = false

    let initialPath: String?

    private var displayTitle: String {
        guard let path = viewModel.currentPath else { return "Videos" }
        // Extract just the last component of the path for display
        let components = path.split(separator: "/")
        return components.last.map(String.init) ?? "Videos"
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
                    List {
                        // Directories section
                        if !viewModel.directories.isEmpty {
                            Section {
                                ForEach(viewModel.directories) { directory in
                                    NavigationLink(destination: DirectoryBrowserView(initialPath: directory.urlPath)) {
                                        DirectoryRow(directory: directory)
                                    }
                                }
                            }
                        }

                        // Videos section
                        if !viewModel.videos.isEmpty {
                            Section {
                                ForEach(viewModel.videos) { video in
                                    Button(action: {
                                        selectedVideo = video
                                    }) {
                                        VideoRow(video: video, serverURL: serverURLManager.serverURL)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

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
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.serverUnreachable {
                        Button(action: {
                            showingServerSetup = true
                        }) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
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
            await viewModel.loadDirectory(initialPath)
        }
    }

    init(initialPath: String? = nil) {
        self.initialPath = initialPath
    }
}

struct DirectoryRow: View {
    let directory: DirectoryItem

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(directory.name)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct VideoRow: View {
    let video: VideoItem
    let serverURL: URL?

    private var thumbnailURL: URL? {
        guard let serverURL = serverURL,
              video.hasThumbnail else { return nil }
        let apiService = APIService()
        return apiService.getThumbnailURL(serverURL: serverURL, videoPath: video.urlPath)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            if let thumbnailURL = thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "film.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                            .frame(width: 60, height: 60)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "film.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
            }

            // Video info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.name)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(video.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct DirectoryBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        DirectoryBrowserView()
    }
}
