import PDFVeCore
import SwiftUI

struct AnnotationToolbar: View {
    @Bindable var annotationVM: AnnotationViewModel

    var body: some View {
        HStack(spacing: 6) {
            // 无工具（恢复正常模式）
            toolButton(systemImage: "cursorarrow", label: "选择") {
                annotationVM.activeTool = .none
            }
            .selected(annotationVM.activeTool == .none)

            Divider()

            // 高亮
            toolButton(systemImage: "highlighter", label: "高亮") {
                annotationVM.activeTool = .highlight(color: annotationVM.drawingColor)
            }
            .selected(isHighlight(annotationVM.activeTool))

            // 下划线
            toolButton(systemImage: "underline", label: "下划线") {
                annotationVM.activeTool = .underline(color: annotationVM.drawingColor)
            }
            .selected(isUnderline(annotationVM.activeTool))

            // 删除线
            toolButton(systemImage: "strikethrough", label: "删除线") {
                annotationVM.activeTool = .strikethrough(color: annotationVM.drawingColor)
            }
            .selected(isStrikethrough(annotationVM.activeTool))

            Divider()

            // 便签
            toolButton(systemImage: "note.text.badge.plus", label: "便签") {
                annotationVM.activeTool = .note
            }
            .selected(annotationVM.activeTool == .note)

            Divider()

            // 画笔
            toolButton(systemImage: "pencil.tip", label: "画笔") {
                annotationVM.activeTool = .drawing(
                    color: annotationVM.drawingColor,
                    lineWidth: annotationVM.drawingLineWidth
                )
            }
            .selected(isDrawing(annotationVM.activeTool))

            // 橡皮擦
            toolButton(systemImage: "eraser", label: "橡皮擦") {
                annotationVM.activeTool = .eraser
            }
            .selected(annotationVM.activeTool == .eraser)

            Divider()

            // 颜色选择器（AC-006-02, AC-010-02）
            colorPicker

            // 线宽选择（AC-010-03，仅绘制模式显示）
            if isDrawing(annotationVM.activeTool) {
                lineWidthPicker
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Sub-components

    private var colorPicker: some View {
        HStack(spacing: 4) {
            ForEach([AnnotationColor.yellow, .green, .blue, .pink, .red], id: \.self) { color in
                Circle()
                    .fill(Color(hex: color.rawValue) ?? .yellow)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle().stroke(Color.primary, lineWidth: annotationVM.drawingColor == color ? 2 : 0)
                    )
                    .onTapGesture {
                        annotationVM.drawingColor = color
                        updateActiveToolColor(color)
                    }
            }
        }
    }

    private var lineWidthPicker: some View {
        HStack(spacing: 4) {
            ForEach(DrawingLineWidth.allCases, id: \.self) { width in
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 20, height: width.rawValue * 2)
                    .foregroundStyle(annotationVM.drawingLineWidth == width ? Color.primary : Color.secondary)
                    .onTapGesture {
                        annotationVM.drawingLineWidth = width
                        if case .drawing(let color, _) = annotationVM.activeTool {
                            annotationVM.activeTool = .drawing(color: color, lineWidth: width)
                        }
                    }
            }
        }
    }

    // MARK: - Helpers

    private func toolButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .help(label)
        .buttonStyle(.plain)
    }

    private func updateActiveToolColor(_ color: AnnotationColor) {
        switch annotationVM.activeTool {
        case .highlight:    annotationVM.activeTool = .highlight(color: color)
        case .underline:    annotationVM.activeTool = .underline(color: color)
        case .strikethrough: annotationVM.activeTool = .strikethrough(color: color)
        case .drawing(_, let lw): annotationVM.activeTool = .drawing(color: color, lineWidth: lw)
        default: break
        }
    }

    private func isHighlight(_ tool: AnnotationTool) -> Bool {
        if case .highlight = tool { return true }; return false
    }
    private func isUnderline(_ tool: AnnotationTool) -> Bool {
        if case .underline = tool { return true }; return false
    }
    private func isStrikethrough(_ tool: AnnotationTool) -> Bool {
        if case .strikethrough = tool { return true }; return false
    }
    private func isDrawing(_ tool: AnnotationTool) -> Bool {
        if case .drawing = tool { return true }; return false
    }
}

// MARK: - View modifier helper

private extension View {
    func selected(_ isSelected: Bool) -> some View {
        self.padding(4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
