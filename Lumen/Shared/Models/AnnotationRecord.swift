import SwiftData
import Foundation

@Model
public final class AnnotationRecord {
    public var id: UUID
    public var documentPath: String
    public var type: String            // AnnotationType.rawValue
    public var pageNumber: Int
    public var colorHex: String
    public var content: String?
    public var selectedText: String?
    public var boundsX: Double
    public var boundsY: Double
    public var boundsWidth: Double
    public var boundsHeight: Double
    public var drawingPathData: Data?
    public var createdAt: Date

    public init(type: AnnotationType, documentPath: String, pageNumber: Int,
         colorHex: String, boundsX: Double, boundsY: Double,
         boundsWidth: Double, boundsHeight: Double) {
        self.id = UUID()
        self.type = type.rawValue
        self.documentPath = documentPath
        self.pageNumber = pageNumber
        self.colorHex = colorHex
        self.boundsX = boundsX
        self.boundsY = boundsY
        self.boundsWidth = boundsWidth
        self.boundsHeight = boundsHeight
        self.createdAt = Date()
    }

    public var annotationType: AnnotationType {
        AnnotationType(rawValue: type) ?? .highlight
    }

    public var bounds: CGRect {
        CGRect(x: boundsX, y: boundsY, width: boundsWidth, height: boundsHeight)
    }
}
