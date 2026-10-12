import SwiftUI

/// One level of the Downloads tree: subfolders first, then videos
struct DownloadsFolderView: View {
    let folder: [String]
    @ObservedObject var viewModel: DownloadsViewModel
    // Edit mode shows a delete button on every tile
    @Binding var isEditing: Bool

    @State private var selectedVideo: DownloadedVideo?
    @State private var videoToDelete: DownloadedVideo?
    @State private var folderToDelete: DownloadFolder?
    @State private var downloadToCancel: PendingDownload?
    @State private var failedDownload: PendingDownload?
    @State private var isRetryingThumbnails = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    private var isRoot: Bool { folder.isEmpty }

    var body: some View {
        let contents = DownloadTree.contents(at: folder, entries: viewModel.entries)

        Group {
            if isRoot && viewModel.entries.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Downloaded Videos")
                        .font(.title2)
                    Text("In the Browse tab, tap \(Image(systemName: "arrow.down.circle")), then tap \(Image(systemName: "arrow.down.circle.fill")) on a video or folder to download it")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(contents.folders) { subfolder in
                            NavigationLink(value: subfolder.path) {
                                DownloadFolderGridItem(folder: subfolder, showsPendingIndicator: !isEditing)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                folderMenu(for: subfolder)
                            }
                            .overlay(alignment: .topTrailing) {
                                if isEditing {
                                    DeleteButton {
                                        folderToDelete = subfolder
                                    }
                                    .padding(8)
                                }
                            }
                        }

                        ForEach(contents.videos) { entry in
                            videoTile(for: entry)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(folder.last ?? "Downloads")
        .toolbar {
            if isRoot {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.hasVideosWithoutThumbnails {
                        Button(action: {
                            isRetryingThumbnails = true
                            Task {
                                await viewModel.retryMissingThumbnails()
                                isRetryingThumbnails = false
                            }
                        }) {
                            if isRetryingThumbnails {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Label("Retry Thumbnails", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(isRetryingThumbnails)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.downloadedVideos.isEmpty {
                        Label(viewModel.formattedTotalSize, systemImage: "internaldrive")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.entries.isEmpty {
                    // Filled while active
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Image(systemName: isEditing ? "trash.fill" : "trash")
                    }
                    .accessibilityLabel(isEditing ? "Done" : "Delete")
                }
            }
        }
        .fullScreenCover(item: $selectedVideo) { video in
            LocalVideoPlayerView(video: video)
                .ignoresSafeArea()
        }
        .alert("Delete Video", isPresented: Binding(
            get: { videoToDelete != nil },
            set: { if !$0 { videoToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                videoToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    videoToDelete = nil // Clear first to avoid accessing deleted object
                    viewModel.deleteVideo(video)
                }
            }
        } message: {
            if let video = videoToDelete {
                Text("Are you sure you want to delete '\(video.videoName)'?")
            }
        }
        .alert("Delete Folder", isPresented: Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        ), presenting: folderToDelete) { subfolder in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteFolder(subfolder.path)
            }
        } message: { subfolder in
            Text(deleteFolderMessage(subfolder))
        }
        .alert("Cancel Download", isPresented: Binding(
            get: { downloadToCancel != nil },
            set: { if !$0 { downloadToCancel = nil } }
        ), presenting: downloadToCancel) { download in
            Button("Keep Downloading", role: .cancel) { }
            Button("Cancel Download", role: .destructive) {
                viewModel.cancelDownload(download.video.urlPath)
            }
        } message: { download in
            Text("Cancel download of '\(download.video.name)'?")
        }
        .alert("Download Failed", isPresented: Binding(
            get: { failedDownload != nil },
            set: { if !$0 { failedDownload = nil } }
        ), presenting: failedDownload) { download in
            Button("Retry") {
                viewModel.retryDownload(download.video.urlPath)
            }
            Button("Remove", role: .destructive) {
                viewModel.cancelDownload(download.video.urlPath)
            }
            Button("Cancel", role: .cancel) { }
        } message: { download in
            if case .failed(let error) = download.state {
                Text(error)
            }
        }
    }

    @ViewBuilder
    private func videoTile(for entry: DownloadEntry) -> some View {
        switch entry {
        case .downloaded(let video):
            DownloadedVideoGridItem(video: video)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedVideo = video
                }
                .overlay(alignment: .topTrailing) {
                    if isEditing {
                        // Single files are deleted without confirmation
                        DeleteButton {
                            viewModel.deleteVideo(video)
                        }
                        .padding(8)
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        videoToDelete = video
                    } label: {
                        Label("Delete Download", systemImage: "trash")
                    }
                }

        case .pending(let download):
            PendingDownloadGridItem(download: download, showsBadge: !isEditing)
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if isEditing {
                        DeleteButton {
                            viewModel.cancelDownload(download.video.urlPath)
                        }
                        .padding(8)
                    }
                }
                .onTapGesture {
                    if case .failed = download.state {
                        failedDownload = download
                    } else {
                        downloadToCancel = download
                    }
                }
                .contextMenu {
                    if case .failed = download.state {
                        Button {
                            viewModel.retryDownload(download.video.urlPath)
                        } label: {
                            Label("Retry Download", systemImage: "arrow.clockwise")
                        }
                    }
                    Button(role: .destructive) {
                        viewModel.cancelDownload(download.video.urlPath)
                    } label: {
                        Label("Cancel Download", systemImage: "xmark")
                    }
                }
        }
    }

    @ViewBuilder
    private func folderMenu(for subfolder: DownloadFolder) -> some View {
        if subfolder.pendingCount > 0 {
            Button {
                viewModel.cancelDownloads(inFolder: subfolder.path)
            } label: {
                Label("Cancel Downloads", systemImage: "xmark")
            }
        }
        if subfolder.downloadedCount > 0 {
            Button(role: .destructive) {
                folderToDelete = subfolder
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }

    private func deleteFolderMessage(_ subfolder: DownloadFolder) -> String {
        let pending = subfolder.pendingCount
        let pendingNote = "\(pending) pending \(pending == 1 ? "download" : "downloads")"

        guard subfolder.downloadedCount > 0 else {
            return "Cancel the \(pendingNote) in '\(subfolder.name)'?"
        }

        var message = "Delete '\(subfolder.name)' and everything in it? "
            + "This will free up \(subfolder.downloadedSize.formattedByteCount)."
        if pending > 0 {
            message += " The \(pendingNote) inside will be cancelled too."
        }
        return message
    }
}

struct DownloadFolderGridItem: View {
    let folder: DownloadFolder
    var showsPendingIndicator = true

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }

                // Something inside is still downloading
                if showsPendingIndicator && folder.pendingCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    .padding(8)
                }
            }

            Text(folder.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(folder.videoCount) \(folder.videoCount == 1 ? "video" : "videos") · \(folder.totalSize.formattedByteCount)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
