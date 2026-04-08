import PDFVeCore
import SwiftUI
import PDFKit

struct AnnotationOverlayView: View {
    @Bindable var annotationVM: AnnotationViewModel
    var readerVM: ReaderViewModel
    @State private var drawingPath: [CGPoint] = []

    // Computed property establishes explicit dependency tracking via @Observable/@Bindable
    private var currentPageAnnotations: [AnnotationRecord] {
        annotationVM.annotations(for: readerVM.currentPage)
    }

    var body: some View {
        Canvas { context, size in
            let pageAnnotations = currentPageAnnotations
            for ann in pageAnnotations {
                drawAnnotation(ann, in: context, viewSize: size)
            }
            if !drawingPath.isEmpty {
                drawLivePath(drawingPath, in: context)
            }
        }
        .allowsHitTesting(true)
        // 单击：橡皮擦删除（AC-010-06）
        .onTapGesture { point in
            if case .eraser = annotationVM.activeTool {
                eraseAt(point)
            }
        }
        // 双击：创建便签（AC-009-01）
        .onTapGesture(count: 2) { point in
            if case .note = annotationVM.activeTool {
                _ = annotationVM.createNote(at: point, pageNumber: readerVM.currentPage)
            }
        }
        // 拖拽：自由绘制（AC-010-01）
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in handleDrag(value) }
                .onEnded { value in handleDragEnd(value) }
        )
        // 右键菜单：文本标注（AC-006-01）
        .contextMenu {
            if annotationVM.hasTextSelection, let selection = annotationVM.currentSelection {
                Button("高亮") {
                    annotationVM.createTextAnnotation(type: .highlight, selection: selection, color: .yellow)
                }
                Button("下划线") {
                    annotationVM.createTextAnnotation(type: .underline, selection: selection, color: .blue)
                }
                Button("删除线") {
                    annotationVM.createTextAnnotation(type: .strikethrough, selection: selection, color: .red)
                }
            }
        }
        // Cmd+Z 撤销绘制（AC-010-04）
        .onKeyPress(.init("z"), phases: .down) { event in
            guard event.modifiers.contains(.command) else { return .ignored }
            annotationVM.undoLastDrawing()
            return .handled
        }
    }

    // MARK: - Drawing helpers

    private func drawAnnotation(_ ann: AnnotationRecord, in context: GraphicsContext, viewSize: CGSize) {
        guard let color = NSColor(hex: ann.colorHex) else { return }
        let bounds = pdfToViewRect(ann.bounds, pageNumber: ann.pageNumber)

        switch ann.annotationType {
        case .highlight:
            context.fill(Path(bounds), with: .color(Color(color).opacity(0.35)))
        case .underline:
            let underlineRect = CGRect(x: bounds.minX, y: bounds.maxY - 2, width: bounds.width, height: 2)
            context.fill(Path(underlineRect), with: .color(Color(color)))
        case .strikethrough:
            let strikeRect = CGRect(x: bounds.minX, y: bounds.midY - 1, width: bounds.width, height: 2)
            context.fill(Path(strikeRect), with: .color(Color(color)))
        case .note:
            let iconRect = CGRect(x: bounds.minX, y: bounds.minY, width: 24, height: 24)
            context.fill(Path(ellipseIn: iconRect), with: .color(.yellow))
        case .drawing:
            drawStoredPath(ann, in: context)
        }
    }

    private func pdfToViewRect(_ rect: CGRect, pageNumber: Int) -> CGRect {
        guard let pdfView = readerVM.pdfView,
              let page = pdfView.document?.page(at: pageNumber - 1) else { return rect }
        let viewRect = pdfView.convert(rect, from: page)
        return pdfView.convert(viewRect, to: nil)
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

    private func eraseAt(_ point: CGPoint) {
        if let hit = annotationVM.annotations(for: readerVM.currentPage)
            .filter({ $0.annotationType == .drawing })
            .first(where: { $0.bounds.insetBy(dx: -10, dy: -10).contains(point) }) {
            annotationVM.deleteAnnotation(id: hit.id)
        }
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
