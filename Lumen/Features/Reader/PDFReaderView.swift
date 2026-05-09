import PDFVeCore
import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel
    var annotationVM: AnnotationViewModel?
    var onSearchSelection: ((String) -> Void)? = nil
    @State private var showSelectionToolbar = false

    var body: some View {
        ZStack {
            PDFViewWrapper(document: document, readerVM: readerVM, annotationVM: annotationVM)
                // 触控板捏合缩放（AC-003-05）
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            readerVM.setZoom(readerVM.zoomLevel * value.magnification)
                        }
                )
                // 键盘快捷键（AC-003-01~04）
                .onKeyPress(.init("+"), action: { readerVM.zoomIn(); return .handled })
                .onKeyPress(.init("-"), action: { readerVM.zoomOut(); return .handled })
                // 键盘翻页：方向键 / 空格 / Page Up/Down
                .onKeyPress(.space, phases: .down) { _ in
                    readerVM.scrollPage(forward: true)
                    return .handled
                }
                .onKeyPress(.downArrow, phases: .down) { _ in
                    readerVM.scrollPage(forward: true)
                    return .handled
                }
                .onKeyPress(.upArrow, phases: .down) { _ in
                    readerVM.scrollPage(forward: false)
                    return .handled
                }
                .onKeyPress(.rightArrow, phases: .down) { _ in
                    readerVM.goToPage(readerVM.currentPage + 1)
                    return .handled
                }
                .onKeyPress(.leftArrow, phases: .down) { _ in
                    readerVM.goToPage(readerVM.currentPage - 1)
                    return .handled
                }
                .onKeyPress(.pageDown, phases: .down) { _ in
                    readerVM.scrollPage(forward: true)
                    return .handled
                }
                .onKeyPress(.pageUp, phases: .down) { _ in
                    readerVM.scrollPage(forward: false)
                    return .handled
                }
                .onKeyPress(.home, phases: .down) { _ in
                    readerVM.goToPage(1)
                    return .handled
                }
                .onKeyPress(.end, phases: .down) { _ in
                    readerVM.goToPage(readerVM.totalPages)
                    return .handled
                }

            // 标注覆盖层（如有 annotationVM）
            if let annotationVM {
                AnnotationOverlayView(annotationVM: annotationVM, readerVM: readerVM)
                    .allowsHitTesting(annotationVM.activeTool != .none)
            }

            // 文字选中浮动工具栏
            if let annotationVM,
               annotationVM.hasTextSelection,
               let selection = annotationVM.currentSelection,
               annotationVM.activeTool == .none {
                VStack {
                    SelectionToolbarView(
                        selection: selection,
                        annotationVM: annotationVM,
                        onCopy: {
                            if let string = selection.string {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(string, forType: .string)
                            }
                        },
                        onSearch: { text in
                            onSearchSelection?(text)
                            readerVM.pdfView?.clearSelection()
                            annotationVM.hasTextSelection = false
                        },
                        onDismiss: {
                            readerVM.pdfView?.clearSelection()
                            annotationVM.hasTextSelection = false
                        }
                    )
                    .padding(.top, 8)
                    Spacer()
                }
                .allowsHitTesting(true)
                .transition(.opacity)
            }
        }
    }
}
