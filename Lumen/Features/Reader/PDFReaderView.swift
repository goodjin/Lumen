import PDFVeCore
import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel
    var annotationVM: AnnotationViewModel?

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

            // 标注覆盖层（如有 annotationVM）
            if let annotationVM {
                AnnotationOverlayView(annotationVM: annotationVM, readerVM: readerVM)
                    .allowsHitTesting(annotationVM.activeTool != .none)
            }
        }
    }
}
