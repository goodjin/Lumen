# P-06: MOD-05 标注工具模块

## 文档信息

- **计划编号**: P-06
- **批次**: 第3批
- **对应架构**: docs/v1/02-architecture/03-mod05-annotation.md
- **优先级**: P0
- **前置依赖**: P-03, P-07（AnnotationRepository，可并行开发，P-07 先完成）

---

## 模块职责

实现高亮、下划线、删除线、便签注释、自由绘制五种标注工具。标注数据通过 AnnotationRepository 持久化（不修改原始 PDF，Rule-001）。对应 PRD: FR-006~010。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-06-01 | AnnotationService（文本标注 CRUD） | 1 | ~120 | P-07 |
| T-06-02 | AnnotationViewModel（工具状态） | 1 | ~100 | T-06-01 |
| T-06-03 | AnnotationOverlayView（Canvas 渲染） | 1 | ~180 | T-06-02 |
| T-06-04 | 文本标注：高亮/下划线/删除线 | 1 | ~80 | T-06-03 |
| T-06-05 | 便签注释（NoteAnnotation） | 1 | ~120 | T-06-03 |
| T-06-06 | 自由绘制（Drawing） | 1 | ~120 | T-06-03 |
| T-06-07 | AnnotationToolbar（工具选择栏） | 1 | ~80 | T-06-02 |

---

## 详细任务定义

### T-06-01: AnnotationService

**输出文件**: `PDF-Ve/Features/Annotation/AnnotationService.swift`

**实现要求**:

```swift
import PDFKit
import Foundation

@MainActor
class AnnotationService {
    private let annotationRepo: AnnotationRepository

    init(repo: AnnotationRepository) {
        self.annotationRepo = repo
    }

    // API-040: 创建文本标注（高亮/下划线/删除线）
    func createTextAnnotation(
        type: AnnotationType,
        selection: PDFSelection,
        color: AnnotationColor,
        documentPath: String
    ) throws -> AnnotationRecord {
        // BOUND-020：校验选区含文字
        guard let text = selection.string, !text.isEmpty else {
            throw AnnotationError.noSelectableText
        }
        // 取第一页的选区 bounds
        guard let page = selection.pages.first,
              let doc = page.document,
              let pageIndex = doc.index(for: page) else {
            throw AnnotationError.noSelectableText
        }
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
    func createNoteAnnotation(
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
    func updateAnnotation(_ record: AnnotationRecord, content: String? = nil, bounds: CGRect? = nil) {
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
    func deleteAnnotation(id: UUID) {
        try? annotationRepo.delete(id: id)
    }

    // API-044: 创建绘制标注
    func createDrawingAnnotation(
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
        // 序列化路径
        let pathData = try? JSONEncoder().encode(path.map { [$0.x, $0.y] })
        record.drawingPathData = pathData
        try? annotationRepo.save(record)
        return record
    }
}

enum AnnotationError: LocalizedError {
    case noSelectableText
    var errorDescription: String? { "选中区域不包含可识别的文字" }
}
```

**验收标准**:
- [ ] `createTextAnnotation` 选区无文字时抛 `AnnotationError.noSelectableText`
- [ ] `createDrawingAnnotation` `path.count < 2` 时返回 nil
- [ ] 所有方法不调用 PDFKit 的标注写入 API（Rule-001）

---

### T-06-02: AnnotationViewModel

**输出文件**: `PDF-Ve/Features/Annotation/AnnotationViewModel.swift`

**实现要求**:

```swift
@MainActor
@Observable
class AnnotationViewModel {
    private let service: AnnotationService
    private let repo: AnnotationRepository

    var annotations: [AnnotationRecord] = []
    var activeTool: AnnotationTool = .none
    var documentPath: String = ""

    init(service: AnnotationService, repo: AnnotationRepository) {
        self.service = service
        self.repo = repo
    }

    // 加载文档标注（Flow-002）
    func loadAnnotations(for documentPath: String) {
        self.documentPath = documentPath
        annotations = (try? repo.fetchAll(for: documentPath)) ?? []
    }

    // 创建文本标注（STATE-002 驱动）
    func createTextAnnotation(type: AnnotationType, selection: PDFSelection, color: AnnotationColor) {
        guard let record = try? service.createTextAnnotation(
            type: type, selection: selection, color: color, documentPath: documentPath
        ) else { return }
        annotations.append(record)
    }

    // 创建便签
    func createNote(at point: CGPoint, pageNumber: Int) -> AnnotationRecord {
        let record = service.createNoteAnnotation(at: point, pageNumber: pageNumber, documentPath: documentPath)
        annotations.append(record)
        return record
    }

    // 更新便签
    func updateNote(_ record: AnnotationRecord, content: String? = nil, bounds: CGRect? = nil) {
        service.updateAnnotation(record, content: content, bounds: bounds)
    }

    // 删除标注（API-043）
    func deleteAnnotation(id: UUID) {
        service.deleteAnnotation(id: id)
        annotations.removeAll { $0.id == id }
    }

    // 完成绘制（API-044）
    func finishDrawing(path: [CGPoint], color: AnnotationColor, lineWidth: DrawingLineWidth, pageNumber: Int) {
        guard let record = service.createDrawingAnnotation(
            path: path, color: color, lineWidth: lineWidth,
            pageNumber: pageNumber, documentPath: documentPath
        ) else { return }
        annotations.append(record)
    }

    // 撤销最近一次绘制（API-045）
    func undoLastDrawing() {
        guard let last = annotations.last(where: { $0.annotationType == .drawing }) else { return }
        deleteAnnotation(id: last.id)
    }

    // 当前页的所有标注
    func annotations(for pageNumber: Int) -> [AnnotationRecord] {
        annotations.filter { $0.pageNumber == pageNumber }
    }
}
```

**验收标准**:
- [ ] `loadAnnotations()` 加载后 `annotations` 包含该文档全部历史标注
- [ ] `deleteAnnotation()` 同步从内存和数据库删除
- [ ] `undoLastDrawing()` 无绘制标注时静默无操作

---

### T-06-03: AnnotationOverlayView（Canvas 渲染）

**输出文件**: `PDF-Ve/Features/Annotation/AnnotationOverlayView.swift`

**实现要求**: 覆盖在 PDFView 上方的透明 Canvas，负责绘制所有标注的视觉效果。

```swift
import SwiftUI
import PDFKit

struct AnnotationOverlayView: View {
    var annotationVM: AnnotationViewModel
    var readerVM: ReaderViewModel
    @State private var drawingPath: [CGPoint] = []

    var body: some View {
        Canvas { context, size in
            // 渲染当前页的标注
            let pageAnnotations = annotationVM.annotations(for: readerVM.currentPage)
            for ann in pageAnnotations {
                drawAnnotation(ann, in: context, viewSize: size)
            }
            // 正在绘制中的路径（实时预览）
            if !drawingPath.isEmpty {
                drawLivePath(drawingPath, in: context)
            }
        }
        .allowsHitTesting(true)
        // 鼠标事件：双击创建便签，拖拽绘制
        .onTapGesture(count: 2) { point in
            handleDoubleTap(at: point)
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in handleDrag(value) }
                .onEnded { value in handleDragEnd(value) }
        )
    }

    private func drawAnnotation(_ ann: AnnotationRecord, in context: GraphicsContext, viewSize: CGSize) {
        guard let color = NSColor(hex: ann.colorHex) else { return }
        let bounds = pdfToViewRect(ann.bounds, pageNumber: ann.pageNumber, viewSize: viewSize)

        switch ann.annotationType {
        case .highlight:
            context.fill(Path(bounds), with: .color(Color(color).opacity(0.35)))
        case .underline:
            let underlineRect = CGRect(x: bounds.minX, y: bounds.maxY - 2, width: bounds.width, height: 2)
            context.fill(Path(underlineRect), with: .color(Color(color)))
        case .strikethrough:
            let midY = bounds.midY
            let strikeRect = CGRect(x: bounds.minX, y: midY - 1, width: bounds.width, height: 2)
            context.fill(Path(strikeRect), with: .color(Color(color)))
        case .note:
            // 便签图标（折叠状态）
            let iconRect = CGRect(x: bounds.minX, y: bounds.minY, width: 24, height: 24)
            context.fill(Path(ellipseIn: iconRect), with: .color(.yellow))
        case .drawing:
            drawStoredPath(ann, in: context)
        }
    }

    // PDF 坐标系转视图坐标系（简化版，实际需要通过 PDFView 获取精确转换）
    private func pdfToViewRect(_ rect: CGRect, pageNumber: Int, viewSize: CGSize) -> CGRect {
        // 通过 readerVM.pdfView 获取精确坐标转换
        guard let pdfView = readerVM.pdfView,
              let page = pdfView.document?.page(at: pageNumber - 1) else { return rect }
        let viewRect = pdfView.convert(rect, from: page)
        return pdfView.convert(viewRect, to: nil)  // 转换到 overlay 坐标
    }

    private func handleDoubleTap(at point: CGPoint) {
        guard case .note = annotationVM.activeTool else { return }
        let pageNumber = readerVM.currentPage
        _ = annotationVM.createNote(at: point, pageNumber: pageNumber)
    }

    private func handleDrag(_ value: DragGesture.Value) {
        guard case .drawing = annotationVM.activeTool else { return }
        drawingPath.append(value.location)
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        guard case .drawing(let color, let lineWidth) = annotationVM.activeTool else {
            drawingPath = []
            return
        }
        annotationVM.finishDrawing(
            path: drawingPath, color: color,
            lineWidth: lineWidth, pageNumber: readerVM.currentPage
        )
        drawingPath = []
    }

    private func drawStoredPath(_ ann: AnnotationRecord, in context: GraphicsContext) {
        guard let data = ann.drawingPathData,
              let points = try? JSONDecoder().decode([[Double]].self, from: data),
              points.count >= 2,
              let color = NSColor(hex: ann.colorHex) else { return }
        var path = Path()
        let cgPoints = points.map { CGPoint(x: $0[0], y: $0[1]) }
        path.move(to: cgPoints[0])
        for pt in cgPoints.dropFirst() { path.addLine(to: pt) }
        context.stroke(path, with: .color(Color(color)), lineWidth: 2.0)
    }

    private func drawLivePath(_ points: [CGPoint], in context: GraphicsContext) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: points[0])
        for pt in points.dropFirst() { path.addLine(to: pt) }
        context.stroke(path, with: .color(.red.opacity(0.8)), lineWidth: 2.0)
    }
}
```

**验收标准**:
- [ ] 高亮显示半透明颜色背景（AC-006-03）
- [ ] 下划线在文本底部显示（AC-007-03）
- [ ] 删除线在文本中部显示（AC-008-02）
- [ ] 画笔拖拽时实时显示路径预览（AC-010-01）
- [ ] 双击空白区域（note 工具激活时）创建便签

---

### T-06-04: 文本标注集成（高亮/下划线/删除线）

**输出文件**: `PDF-Ve/Features/Annotation/TextAnnotationHandler.swift`（或集成到 PDFViewWrapper）

**实现要求**: 在 PDFViewWrapper 的 Coordinator 中监听 PDFView 文本选择变化，当用户选中文字后，通过右键菜单或工具栏触发创建标注。

```swift
// 在 PDFViewWrapper Coordinator 添加：
// 监听 PDFViewSelectionChanged 通知
@objc func selectionChanged(_ notification: Notification) {
    guard let pdfView = notification.object as? PDFView else { return }
    Task { @MainActor in
        let hasSelection = pdfView.currentSelection?.string?.isEmpty == false
        self.annotationVM.hasTextSelection = hasSelection
        self.annotationVM.currentSelection = pdfView.currentSelection
    }
}
```

右键菜单（在 AnnotationOverlayView 上）：
```swift
.contextMenu {
    if annotationVM.hasTextSelection {
        Button("高亮") { annotationVM.createTextAnnotation(type: .highlight, ...) }
        Button("下划线") { annotationVM.createTextAnnotation(type: .underline, ...) }
        Button("删除线") { annotationVM.createTextAnnotation(type: .strikethrough, ...) }
    }
}
```

**验收标准**:
- [ ] 选中文本后工具栏/右键菜单显示标注选项（AC-006-01）
- [ ] 支持 5 种高亮颜色（AC-006-02）
- [ ] 非文字区域不触发标注（BOUND-020）

---

### T-06-05: 便签注释

便签的展开/折叠状态（STATE-005）和可拖动位置（BOUND-021）在 AnnotationOverlayView 中处理，具体实现为：
- 折叠状态：绘制小图标
- 展开状态：显示 NotePopoverView（SwiftUI Popover 或自定义 overlay）
- 拖动：DragGesture 更新 bounds 并调用 `annotationVM.updateNote()`

**输出文件**: `PDF-Ve/Features/Annotation/NotePopoverView.swift`

**验收标准**:
- [ ] 双击空白区域创建便签（AC-009-01）
- [ ] 便签可拖动（AC-009-04）
- [ ] 点击外部折叠（AC-009-05），点击图标展开（AC-009-06）
- [ ] 右键删除（AC-009-08）

---

### T-06-06: 自由绘制

已在 T-06-03 AnnotationOverlayView 中实现绘制逻辑。本任务补充橡皮擦工具：

```swift
// 橡皮擦：点击时查找命中的 drawing 标注并删除（AC-010-06）
.onTapGesture { point in
    guard case .eraser = annotationVM.activeTool else { return }
    // 查找最近的 drawing 标注（碰撞检测）
    if let hit = annotationVM.annotations(for: readerVM.currentPage)
        .filter({ $0.annotationType == .drawing })
        .first(where: { $0.bounds.insetBy(dx: -10, dy: -10).contains(point) }) {
        annotationVM.deleteAnnotation(id: hit.id)
    }
}
```

**验收标准**:
- [ ] 橡皮擦点击绘制标注可删除（AC-010-06）
- [ ] Cmd+Z 撤销最近一次绘制（AC-010-04）

---

### T-06-07: AnnotationToolbar

**输出文件**: `PDF-Ve/Features/Annotation/AnnotationToolbar.swift`

工具栏提供工具切换按钮（无/高亮/下划线/删除线/便签/画笔/橡皮擦）和颜色选择器。

**验收标准**:
- [ ] 工具栏可切换当前激活工具
- [ ] 颜色选择器显示并可选色

---

## 验收清单

- [ ] 选中文字 → 高亮/下划线/删除线 创建正确（AC-006~008）
- [ ] 高亮支持 5 种颜色（AC-006-02）
- [ ] 便签创建/编辑/拖动/折叠展开/删除（AC-009 全部）
- [ ] 画笔绘制/颜色选择/粗细选择/Cmd+Z 撤销/橡皮擦删除（AC-010 全部）
- [ ] 所有标注持久化（重开应用后标注仍存在）

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| API-040 createTextAnnotation | T-06-01 | ✅ |
| API-041 createNoteAnnotation | T-06-01 | ✅ |
| API-042 updateAnnotation | T-06-01 | ✅ |
| API-043 deleteAnnotation | T-06-01 | ✅ |
| API-044 appendDrawingStroke | T-06-01 | ✅ |
| API-045 undoLastDrawing | T-06-02 | ✅ |
| Rule-001 标注不修改原始PDF | T-06-01（不调用PDFKit写入） | ✅ |
| STATE-002 标注创建状态机 | T-06-02, T-06-04 | ✅ |
| STATE-005 便签展开状态机 | T-06-05 | ✅ |
| BOUND-020 文本标注选区 | T-06-01 | ✅ |
| BOUND-021 便签位置 | T-06-05 | ✅ |
| BOUND-022 自由绘制 | T-06-01, T-06-06 | ✅ |
| AC-006-01~06 | T-06-04, T-06-03 | ✅ |
| AC-007-01~04 | T-06-04 | ✅ |
| AC-008-01~03 | T-06-04 | ✅ |
| AC-009-01~08 | T-06-05 | ✅ |
| AC-010-01~06 | T-06-03, T-06-06 | ✅ |
