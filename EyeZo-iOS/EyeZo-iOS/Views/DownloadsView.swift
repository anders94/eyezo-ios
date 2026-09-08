import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var selectedVideo: DownloadedVideo?
    @State private var videoToDelete: DownloadedVideo?
    @State private var isRetryingThumbnails = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.downloadedVideos.isEmpty && viewModel.inProgressDownloads.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Downloaded Videos")
                            .font(.title2)
                        Text("Long-press videos in Browse tab to download")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // In-progress downloads
                            if !viewModel.inProgressDownloads.isEmpty {
                                sectionHeader("Downloading")

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.inProgressDownloads) { download in
                                        InProgressDownloadGridItem(download: download)
                                    }
                                }
                            }

                            // Completed downloads
                            if !viewModel.downloadedVideos.isEmpty {
                                if !viewModel.inProgressDownloads.isEmpty {
                                    sectionHeader("Downloaded")
                                }

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.downloadedVideos) { video in
                                        DownloadedVideoGridItem(video: video)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedVideo = video
                                            }
                                            .onLongPressGesture {
                                                videoToDelete = video
                                            }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
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
            .fullScreenCover(item: $selectedVideo, onDismiss: {
                Task {
                    await viewModel.loadDownloadedVideos()
                }
            }) { video in
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
        }
        .task {
            await viewModel.loadDownloadedVideos()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
    }
}
