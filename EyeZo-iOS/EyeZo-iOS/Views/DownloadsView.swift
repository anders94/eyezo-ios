import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var selectedVideo: DownloadedVideo?
    @State private var videoToDelete: DownloadedVideo?

    var body: some View {
        NavigationView {
            Group {
                if viewModel.downloadedVideos.isEmpty {
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
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.downloadedVideos.isEmpty {
                        Text(viewModel.formattedTotalSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .fullScreenCover(item: $selectedVideo) { video in
                LocalVideoPlayerView(video: video)
                    .ignoresSafeArea()
            }
            .alert("Delete Video", isPresented: .constant(videoToDelete != nil), presenting: videoToDelete) { video in
                Button("Cancel", role: .cancel) {
                    videoToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    viewModel.deleteVideo(video)
                    videoToDelete = nil
                }
            } message: { video in
                Text("Are you sure you want to delete '\(video.videoName)'?")
            }
        }
        .task {
            await viewModel.loadDownloadedVideos()
        }
    }
}
