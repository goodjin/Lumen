import PDFKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.pdfve", category: "ReaderViewModel")

// 共享 PDFView 注册表，解决 HSplitView 导致的实例不一致问题
@MainActor
public class PDFViewRegistry {
    public static let shared = PDFViewRegistry()
    private init() {}

    // 存储当前活动的 PDFView
    public weak var currentPDFView: PDFView?
    public var currentDocument: PDFDocument?

    public func register(_ pdfView: PDFView, document: PDFDocument) {
        currentPDFView = pdfView
        currentDocument = document
        logger.info("PDFView registered: \(pdfView.hashValue)")
    }

    public func unregister() {
        currentPDFView = nil
        currentDocument = nil
    }
}

@MainActor
@Observable
public class ReaderViewModel {
    public init() {}
    public enum ZoomMode { case actual, fitWidth, fitPage }

    public var currentPage: Int = 1
    public var totalPages: Int = 0
    public var zoomLevel: Double = 1.0          // 1.0 = 100%
    public var zoomMode: ZoomMode = .actual
    public var isFullscreen: Bool = false

    // 供 PDFViewWrapper 持有真实的 PDFView 引用
    public weak var pdfView: PDFView?

    // API-010: 跳转页码（BOUND-010：clamp）
    public func goToPage(_ pageNumber: Int) {
        // 优先使用本实例的 pdfView，否则从全局注册表获取
        let targetPDFView = self.pdfView ?? PDFViewRegistry.shared.currentPDFView
        let doc = self.pdfView?.document ?? PDFViewRegistry.shared.currentDocument

        let docPageCount = doc?.pageCount ?? totalPages
        print(">>> goToPage called: \(pageNumber), docPageCount: \(docPageCount), pdfView: \(targetPDFView == nil ? "nil" : "set")")

        guard docPageCount > 0 else {
            print(">>> goToPage failed: docPageCount is 0")
            return
        }

        guard let pdfView = targetPDFView else {
            print(">>> goToPage failed: pdfView is nil")
            return
        }

        let clamped = max(1, min(pageNumber, docPageCount))
        print(">>> goToPage clamped: \(clamped)")

        guard let page = pdfView.document?.page(at: clamped - 1) else {
            print(">>> goToPage failed: cannot get page at index \(clamped - 1)")
            return
        }

        print(">>> goToPage executing: go(to: page \(clamped))")
        pdfView.go(to: page)
        // 同步更新 currentPage
        currentPage = clamped
    }

    // API-011: 缩放系列
    public func zoomIn() {
        let newLevel = min(zoomLevel + 0.1, 5.0)
        setZoom(newLevel)
    }

    public func zoomOut() {
        let newLevel = max(zoomLevel - 0.1, 0.1)
        setZoom(newLevel)
    }

    public func setZoom(_ level: Double) {
        let clamped = max(0.1, min(level, 5.0))
        zoomLevel = clamped
        zoomMode = .actual
        pdfView?.scaleFactor = clamped
    }

    public func setZoomMode(_ mode: ZoomMode) {
        zoomMode = mode
        switch mode {
        case .actual:
            pdfView?.scaleFactor = 1.0
            zoomLevel = 1.0
        case .fitWidth:
            pdfView?.autoScales = false
            if let page = pdfView?.currentPage,
               let view = pdfView {
                let pageWidth = page.bounds(for: .mediaBox).width
                let viewWidth = view.bounds.width - 20
                let scale = viewWidth / pageWidth
                pdfView?.scaleFactor = scale
                zoomLevel = scale
            }
        case .fitPage:
            pdfView?.autoScales = true
            zoomLevel = Double(pdfView?.scaleFactor ?? 1.0)
        }
    }

    // API-012: 全屏切换
    public func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
        isFullscreen.toggle()
    }

    // 由 PDFViewWrapper Coordinator 回调，同步当前页码
    public func updateCurrentPage(_ page: Int) {
        currentPage = page
    }
}
