import PDFKit
import SwiftUI

@MainActor
@Observable
public class AnnotationViewModel {
    private let service: AnnotationService
    private let repo: AnnotationRepository

    public var annotations: [AnnotationRecord] = []
    public var activeTool: AnnotationTool = .none
    public var documentPath: String = ""

    // 文本选区状态（T-06-04 使用）
    public var hasTextSelection: Bool = false
    public var currentSelection: PDFSelection?

    // 当前画笔颜色/粗细（供 toolbar 绑定）
    public var drawingColor: AnnotationColor = .red
    public var drawingLineWidth: DrawingLineWidth = .medium

    public init(service: AnnotationService, repo: AnnotationRepository) {
        self.service = service
        self.repo = repo
    }

    // 加载文档标注（Flow-002）
    public func loadAnnotations(for documentPath: String) {
        self.documentPath = documentPath
        annotations = (try? repo.fetchAll(for: documentPath)) ?? []
    }

    // 创建文本标注（STATE-002 驱动）
    public func createTextAnnotation(type: AnnotationType, selection: PDFSelection, color: AnnotationColor) {
        guard let record = try? service.createTextAnnotation(
            type: type, selection: selection, color: color, documentPath: documentPath
        ) else { return }
        annotations.append(record)
    }

    // 创建便签
    public func createNote(at point: CGPoint, pageNumber: Int) -> AnnotationRecord {
        let record = service.createNoteAnnotation(at: point, pageNumber: pageNumber, documentPath: documentPath)
        annotations.append(record)
        return record
    }

    // 更新便签
    public func updateNote(_ record: AnnotationRecord, content: String? = nil, bounds: CGRect? = nil) {
        service.updateAnnotation(record, content: content, bounds: bounds)
    }

    // 删除标注（API-043）
    public func deleteAnnotation(id: UUID) {
        service.deleteAnnotation(id: id)
        annotations.removeAll { $0.id == id }
    }

    // 完成绘制（API-044）
    public func finishDrawing(path: [CGPoint], color: AnnotationColor, lineWidth: DrawingLineWidth, pageNumber: Int) {
        guard let record = service.createDrawingAnnotation(
            path: path, color: color, lineWidth: lineWidth,
            pageNumber: pageNumber, documentPath: documentPath
        ) else { return }
        annotations.append(record)
    }

    // 撤销最近一次绘制（API-045）
    public func undoLastDrawing() {
        guard let last = annotations.last(where: { $0.annotationType == .drawing }) else { return }
        deleteAnnotation(id: last.id)
    }

    // 当前页的所有标注
    public func annotations(for pageNumber: Int) -> [AnnotationRecord] {
        annotations.filter { $0.pageNumber == pageNumber }
    }
}
