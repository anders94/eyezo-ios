//
//  EyeZoTests.swift
//  EyeZoTests
//
//  Created by Anders Brownworth on 5/16/26.
//

import Foundation
import Testing
@testable import EyeZo

@MainActor
struct DownloadTreeTests {

    private func entry(_ urlPath: String, size: Int64 = 100, state: DownloadState = .queued) -> DownloadEntry {
        let name = DownloadTree.components(forURLPath: urlPath).last ?? urlPath
        let video = VideoItem(
            name: name, path: urlPath, relativePath: urlPath, urlPath: urlPath,
            size: size, modified: 0, extension: ".mp4", mimeType: "video/mp4",
            thumbnailUrl: nil, duration: nil, watchPosition: nil, lastWatched: nil
        )
        return .pending(PendingDownload(video: video, serverURL: URL(string: "http://localhost:3000")!, state: state, queuePosition: 1))
    }

    @Test func decodesPercentEncodedSegments() {
        #expect(DownloadTree.components(forURLPath: "My%20Movies/Video%201.mp4") == ["My Movies", "Video 1.mp4"])
        #expect(DownloadTree.folder(forURLPath: "My%20Movies/Video%201.mp4") == ["My Movies"])
        #expect(DownloadTree.folder(forURLPath: "Video.mp4") == [])
    }

    @Test func rootListsTopLevelFoldersAndFiles() {
        let entries = [entry("Movies/Video.mp4"), entry("Movies/Sci-Fi/Alien.mp4"), entry("Clip.mp4")]
        let contents = DownloadTree.contents(at: [], entries: entries)

        #expect(contents.folders.map(\.name) == ["Movies"])
        #expect(contents.folders.first?.videoCount == 2)
        #expect(contents.folders.first?.totalSize == 200)
        #expect(contents.videos.map(\.name) == ["Clip.mp4"])
    }

    @Test func nestedFolderListsOnlyItsChildren() {
        let entries = [entry("Movies/Video.mp4"), entry("Movies/Sci-Fi/Alien.mp4"), entry("Shows/Pilot.mp4")]
        let contents = DownloadTree.contents(at: ["Movies"], entries: entries)

        #expect(contents.folders.map(\.path) == [["Movies", "Sci-Fi"]])
        #expect(contents.videos.map(\.name) == ["Video.mp4"])
    }

    @Test func sortsByNaturalNameOrder() {
        let entries = [entry("Episode 10.mp4"), entry("Episode 2.mp4"), entry("b/x.mp4"), entry("A/x.mp4")]
        let contents = DownloadTree.contents(at: [], entries: entries)

        #expect(contents.folders.map(\.name) == ["A", "b"])
        #expect(contents.videos.map(\.name) == ["Episode 2.mp4", "Episode 10.mp4"])
    }

    @Test func folderExistsOnlyWhileItHasContents() {
        let entries = [entry("Movies/Sci-Fi/Alien.mp4")]
        #expect(DownloadTree.folderExists(["Movies"], in: entries))
        #expect(DownloadTree.folderExists(["Movies", "Sci-Fi"], in: entries))
        #expect(!DownloadTree.folderExists(["Shows"], in: entries))
        #expect(!DownloadTree.folderExists(["Movies"], in: []))
    }

    @Test func folderMatchingIsPerComponent() {
        // "Movies 2" must not count as inside "Movies"
        #expect(!DownloadTree.urlPath("Movies%202/Video.mp4", isInFolder: ["Movies"]))
        #expect(DownloadTree.urlPath("Movies/Sci-Fi/Alien.mp4", isInFolder: ["Movies"]))
    }
}
