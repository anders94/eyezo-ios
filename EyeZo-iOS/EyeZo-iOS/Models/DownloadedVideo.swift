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

    var formattedSize: String {
        let bytes = Double(fileSize)
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
        }
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
