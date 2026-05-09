import PDFKit
import SwiftUI

/// 标注操作记录，用于撤销/重做
private enum AnnotationAction {
    case created(AnnotationRecord)
    case deleted(AnnotationRecord)
}

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
    public var selectionBoundsInView: CGRect?  // 选区在 SwiftUI 视图坐标系中的位置

    // 当前画笔颜色/粗细（供 toolbar 绑定）
    public var drawingColor: AnnotationColor = .red
    public var drawingLineWidth: DrawingLineWidth = .medium

    // 撤销/重做栈
    private var undoStack: [AnnotationAction] = []
    private var redoStack: [AnnotationAction] = []
    private let maxUndoDepth = 50

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init(service: AnnotationService, repo: AnnotationRepository) {
        self.service = service
        self.repo = repo
    }

    // 加载文档标注（Flow-002）
    public func loadAnnotations(for documentPath: String) {
        self.documentPath = documentPath
        annotations = (try? repo.fetchAll(for: documentPath)) ?? []
        undoStack = []
        redoStack = []
    }

    // 创建文本标注（STATE-002 驱动）
    public func createTextAnnotation(type: AnnotationType, selection: PDFSelection, color: AnnotationColor) {
        guard let record = try? service.createTextAnnotation(
            type: type, selection: selection, color: color, documentPath: documentPath
        ) else { return }
        annotations.append(record)
        pushUndo(.created(record))
    }

    // 创建便签
    public func createNote(at point: CGPoint, pageNumber: Int) -> AnnotationRecord {
        let record = service.createNoteAnnotation(at: point, pageNumber: pageNumber, documentPath: documentPath)
        annotations.append(record)
        pushUndo(.created(record))
        return record
    }

    // 更新便签
    public func updateNote(_ record: AnnotationRecord, content: String? = nil, bounds: CGRect? = nil) {
        service.updateAnnotation(record, content: content, bounds: bounds)
    }

    // 删除标注（API-043）
    public func deleteAnnotation(id: UUID) {
        guard let record = annotations.first(where: { $0.id == id }) else { return }
        service.deleteAnnotation(id: id)
        annotations.removeAll { $0.id == id }
        pushUndo(.deleted(record))
    }

    // 完成绘制（API-044）
    public func finishDrawing(path: [CGPoint], color: AnnotationColor, lineWidth: DrawingLineWidth, pageNumber: Int) {
        guard let record = service.createDrawingAnnotation(
            path: path, color: color, lineWidth: lineWidth,
            pageNumber: pageNumber, documentPath: documentPath
        ) else { return }
        annotations.append(record)
        pushUndo(.created(record))
    }

    // 撤销最近一次绘制（API-045，保留向后兼容）
    public func undoLastDrawing() {
        guard let last = annotations.last(where: { $0.annotationType == .drawing }) else { return }
        deleteAnnotation(id: last.id)
    }

    // 通用撤销（Cmd+Z）
    public func undo() {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .created(let record):
            service.deleteAnnotation(id: record.id)
            annotations.removeAll { $0.id == record.id }
            redoStack.append(.created(record))
        case .deleted(let record):
            // 重新保存已删除的标注
            try? repo.save(record)
            annotations.append(record)
            redoStack.append(.deleted(record))
        }
    }

    // 通用重做（Cmd+Shift+Z）
    public func redo() {
        guard let action = redoStack.popLast() else { return }
        switch action {
        case .created(let record):
            try? repo.save(record)
            annotations.append(record)
            undoStack.append(.created(record))
        case .deleted(let record):
            service.deleteAnnotation(id: record.id)
            annotations.removeAll { $0.id == record.id }
            undoStack.append(.deleted(record))
        }
    }

    private func pushUndo(_ action: AnnotationAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack = []  // 新操作清空重做栈
    }

    // 当前页的所有标注
    public func annotations(for pageNumber: Int) -> [AnnotationRecord] {
        annotations.filter { $0.pageNumber == pageNumber }
    }
}
