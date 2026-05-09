import PDFVeCore
import SwiftUI
import PDFKit

/// 文字选中后显示的浮动工具栏
struct SelectionToolbarView: View {
    let selection: PDFSelection
    var annotationVM: AnnotationViewModel
    var onCopy: () -> Void
    var onSearch: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onCopy()
                onDismiss()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                annotationVM.createTextAnnotation(type: .highlight, selection: selection, color: .yellow)
                onDismiss()
            } label: {
                Label("高亮", systemImage: "highlighter")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Button {
                annotationVM.createTextAnnotation(type: .underline, selection: selection, color: .blue)
                onDismiss()
            } label: {
                Label("下划线", systemImage: "underline")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                // 搜索选中文字
                onSearch(selection.string ?? "")
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
    }
}
