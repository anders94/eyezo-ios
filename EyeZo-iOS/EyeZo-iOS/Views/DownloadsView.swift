import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var selectedVideo: DownloadedVideo?
    @State private var videoToDelete: DownloadedVideo?
    @State private var isRetryingThumbnails = false

    var body: some View {
        NavigationView {
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
                    List {
                        // Storage info section
                        Section {
                            HStack {
                                Label("Storage Used", systemImage: "internaldrive")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                Spacer()
                                Text(viewModel.formattedTotalSize)
                                    .foregroundColor(.secondary)
                                    .font(.body.monospacedDigit())
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                        }
                        .listRowBackground(Color.clear)

                        // In-progress downloads section
                        if !viewModel.inProgressDownloads.isEmpty {
                            Section(header: Text("Downloading")) {
                                ForEach(viewModel.inProgressDownloads) { download in
                                    InProgressDownloadRow(download: download)
                                }
                            }
                        }

                        // Completed downloads section
                        if !viewModel.downloadedVideos.isEmpty {
                            Section(header: Text("Downloaded")) {
                                ForEach(viewModel.downloadedVideos) { video in
                                    DownloadedVideoRow(video: video)
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
        }
        .task {
            await viewModel.loadDownloadedVideos()
        }
    }
}
