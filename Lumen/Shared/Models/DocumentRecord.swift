import SwiftData
import Foundation

@Model
public final class DocumentRecord {
    public var filePath: String
    public var fileName: String
    public var pageCount: Int
    public var lastOpenedAt: Date
    public var lastViewedPage: Int
    public var zoomLevel: Double

    public init(filePath: String, fileName: String, pageCount: Int) {
        self.filePath = filePath
        self.fileName = fileName
        self.pageCount = pageCount
        self.lastOpenedAt = Date()
        self.lastViewedPage = 1
        self.zoomLevel = 1.0
    }
}
