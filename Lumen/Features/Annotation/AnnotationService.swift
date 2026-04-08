import PDFKit
import Foundation

@MainActor
public class AnnotationService {
    private let annotationRepo: AnnotationRepository

    public init(repo: AnnotationRepository) {
        self.annotationRepo = repo
    }

    // API-040: 创建文本标注（高亮/下划线/删除线）
    public func createTextAnnotation(
        type: AnnotationType,
        selection: PDFSelection,
        color: AnnotationColor,
        documentPath: String
    ) throws -> AnnotationRecord {
        // BOUND-020：校验选区含文字
        guard let text = selection.string, !text.isEmpty else {
            throw AnnotationError.noSelectableText
        }
        guard let page = selection.pages.first,
              let doc = page.document else {
            throw AnnotationError.noSelectableText
        }
        let pageIndex = doc.index(for: page)
        let bounds = selection.bounds(for: page)
        let record = AnnotationRecord(
            type: type,
            documentPath: documentPath,
            pageNumber: pageIndex + 1,
            colorHex: color.rawValue,
            boundsX: bounds.origin.x,
            boundsY: bounds.origin.y,
            boundsWidth: bounds.size.width,
            boundsHeight: bounds.size.height
        )
        record.selectedText = String(text.prefix(10000))  // BOUND-020
        try annotationRepo.save(record)
        return record
    }

    // API-041: 创建便签注释
    public func createNoteAnnotation(
        at point: CGPoint,
        pageNumber: Int,
        documentPath: String
    ) -> AnnotationRecord {
        let record = AnnotationRecord(
            type: .note,
            documentPath: documentPath,
            pageNumber: pageNumber,
            colorHex: AnnotationColor.yellow.rawValue,
            boundsX: point.x,
            boundsY: point.y,
            boundsWidth: 200,
            boundsHeight: 100
        )
        try? annotationRepo.save(record)
        return record
    }

    // API-042: 更新标注（便签内容/位置）
    public func updateAnnotation(_ record: AnnotationRecord, content: String? = nil, bounds: CGRect? = nil) {
        if let content { record.content = content }
        if let bounds {
            record.boundsX = bounds.origin.x
            record.boundsY = bounds.origin.y
            record.boundsWidth = bounds.size.width
            record.boundsHeight = bounds.size.height
        }
        try? annotationRepo.save(record)
    }

    // API-043: 删除标注
    public func deleteAnnotation(id: UUID) {
        try? annotationRepo.delete(id: id)
    }

    // API-044: 创建绘制标注
    public func createDrawingAnnotation(
        path: [CGPoint],
        color: AnnotationColor,
        lineWidth: DrawingLineWidth,
        pageNumber: Int,
        documentPath: String
    ) -> AnnotationRecord? {
        guard path.count >= 2 else { return nil }  // BOUND-022
        let xs = path.map { $0.x }
        let ys = path.map { $0.y }
        let bounds = CGRect(
            x: xs.min()!, y: ys.min()!,
            width: xs.max()! - xs.min()!,
            height: ys.max()! - ys.min()!
        ).insetBy(dx: -lineWidth.rawValue, dy: -lineWidth.rawValue)

        let record = AnnotationRecord(
            type: .drawing,
            documentPath: documentPath,
            pageNumber: pageNumber,
            colorHex: color.rawValue,
            boundsX: bounds.origin.x,
            boundsY: bounds.origin.y,
            boundsWidth: bounds.size.width,
            boundsHeight: bounds.size.height
        )
        let pathData = try? JSONEncoder().encode(path.map { [$0.x, $0.y] })
        record.drawingPathData = pathData
        try? annotationRepo.save(record)
        return record
    }
}

public enum AnnotationError: LocalizedError {
    case noSelectableText
    public var errorDescription: String? { "选中区域不包含可识别的文字" }
}
