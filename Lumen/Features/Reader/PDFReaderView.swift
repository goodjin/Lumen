import PDFVeCore
import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel
    var annotationVM: AnnotationViewModel?
    var searchVM: SearchViewModel?
    var onSearchSelection: ((String) -> Void)? = nil

    var body: some View {
        ZStack {
            PDFViewWrapper(document: document, readerVM: readerVM, annotationVM: annotationVM, searchVM: searchVM)
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
               annotationVM.activeTool == .none,
               let bounds = annotationVM.selectionBoundsInView,
               bounds.width > 0, bounds.height > 0 {
                GeometryReader { geo in
                    let toolbarHeight: CGFloat = 44
                    let padding: CGFloat = 8
                    let viewH = geo.size.height
                    let viewW = geo.size.width
                    let selBottom = bounds.maxY
                    let selTop = bounds.minY

                    // Y：选区下方有空间则显示在下方，否则显示在上方
                    let rawCy: CGFloat = selBottom + toolbarHeight + padding * 2 > viewH
                        ? selTop - padding - toolbarHeight / 2
                        : selBottom + padding + toolbarHeight / 2
                    let cy = max(toolbarHeight / 2 + padding,
                                 min(rawCy, viewH - toolbarHeight / 2 - padding))

                    // X：以选区中心为基准，限制在视图范围内
                    let estWidth: CGFloat = 280
                    let cx = max(estWidth / 2 + padding,
                                 min(bounds.midX, viewW - estWidth / 2 - padding))

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
                            annotationVM.selectionBoundsInView = nil
                        },
                        onDismiss: {
                            readerVM.pdfView?.clearSelection()
                            annotationVM.hasTextSelection = false
                            annotationVM.selectionBoundsInView = nil
                        }
                    )
                    .fixedSize()
                    .position(x: cx, y: cy)
                }
                .allowsHitTesting(true)
                .transition(.opacity)
            }
        }
    }
}
