import Foundation
import CoreData

@objc(DownloadedVideo)
public class DownloadedVideo: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var videoName: String
    @NSManaged public var originalPath: String
    @NSManaged public var urlPath: String
    @NSManaged public var fileSize: Int64
    @NSManaged public var localFilePath: String
    @NSManaged public var thumbnailPath: String?
    @NSManaged public var duration: Double
    @NSManaged public var downloadedDate: Date
    @NSManaged public var fileExtension: String
    @NSManaged public var mimeType: String
    @NSManaged public var serverURL: String
    @NSManaged public var watchPosition: Double
    @NSManaged public var lastWatchedDate: Date?

    /// Root of all downloaded files. Its absolute path includes the app's container ID,
    /// which changes when the app is reinstalled, so files are always located by name
    /// relative to this rather than by a stored absolute path.
    static var downloadsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.eyezo.app/downloads")
    }

    // localFilePath/thumbnailPath hold a file name (older records hold a full path
    // from a previous container), so only the last component is used
    var localFileURL: URL {
        Self.downloadsDirectory
            .appendingPathComponent("videos")
            .appendingPathComponent((localFilePath as NSString).lastPathComponent)
    }

    var thumbnailURL: URL? {
        guard let thumbnailPath = thumbnailPath else { return nil }
        return Self.downloadsDirectory
            .appendingPathComponent("thumbnails")
            .appendingPathComponent((thumbnailPath as NSString).lastPathComponent)
    }

    var watchPercentage: Double {
        guard duration > 0, watchPosition > 0 else { return 0 }
        return min((watchPosition / duration) * 100, 100)
    }

    var formattedSize: String {
        fileSize.formattedByteCount
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let secs = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

extension DownloadedVideo {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadedVideo> {
        return NSFetchRequest<DownloadedVideo>(entityName: "DownloadedVideo")
    }
}
