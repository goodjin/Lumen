import SwiftData
import Foundation

@Model
public final class BookmarkRecord {
    public var id: UUID
    public var documentPath: String
    public var pageNumber: Int
    public var name: String
    public var createdAt: Date

    public init(documentPath: String, pageNumber: Int) {
        self.id = UUID()
        self.documentPath = documentPath
        self.pageNumber = pageNumber
        self.name = "第\(pageNumber)页"
        self.createdAt = Date()
    }
}
