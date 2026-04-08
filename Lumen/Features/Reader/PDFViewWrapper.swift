import PDFVeCore
import SwiftUI
import PDFKit
import os.log

private let pdfWrapperLogger = Logger(subsystem: "com.pdfve", category: "PDFViewWrapper")

struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel
    var annotationVM: AnnotationViewModel?

    func makeNSView(context: Context) -> PDFView {
        print(">>> PDFViewWrapper.makeNSView called, document pages: \(document.pageCount)")
        pdfWrapperLogger.info("makeNSView called, document pages: \(document.pageCount)")
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = false
        pdfView.displayDirection = .vertical
        // 将 pdfView 引用传给 ViewModel
        readerVM.pdfView = pdfView
        readerVM.totalPages = document.pageCount
        // 注册到全局注册表
        PDFViewRegistry.shared.register(pdfView, document: document)
        pdfWrapperLogger.info("readerVM.pdfView set, totalPages: \(document.pageCount)")
        // 监听页面变化通知
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        // 监听文字选区变化（T-06-04）
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // 始终更新 totalPages 以确保准确
        readerVM.totalPages = document.pageCount

        // 更新文档（当打开新文件时）
        if pdfView.document !== document {
            pdfView.document = document
            PDFViewRegistry.shared.register(pdfView, document: document)
            print(">>> PDFViewWrapper.updateNSView: document updated, pages: \(document.pageCount)")
        }
        // 更新缩放
        if abs(pdfView.scaleFactor - readerVM.zoomLevel) > 0.001 {
            pdfView.scaleFactor = readerVM.zoomLevel
        }
        context.coordinator.annotationVM = annotationVM
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(readerVM: readerVM, annotationVM: annotationVM)
    }

    class Coordinator: NSObject {
        let readerVM: ReaderViewModel
        var annotationVM: AnnotationViewModel?

        init(readerVM: ReaderViewModel, annotationVM: AnnotationViewModel?) {
            self.readerVM = readerVM
            self.annotationVM = annotationVM
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let doc = pdfView.document else { return }
            let index = doc.index(for: currentPage)
            Task { @MainActor in
                self.readerVM.updateCurrentPage(index + 1)
                self.readerVM.zoomLevel = Double(pdfView.scaleFactor)
            }
        }

        // T-06-04: 监听文字选区变化，更新 annotationVM
        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            Task { @MainActor in
                let hasSelection = pdfView.currentSelection?.string?.isEmpty == false
                self.annotationVM?.hasTextSelection = hasSelection
                self.annotationVM?.currentSelection = pdfView.currentSelection
            }
        }
    }
}
