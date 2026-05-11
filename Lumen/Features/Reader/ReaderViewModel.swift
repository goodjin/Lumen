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
    public enum DisplayMode: String, CaseIterable {
        case singleContinuous = "单页连续"
        case single = "单页"
        case twoContinuous = "双页连续"
        case two = "双页"
    }
    public enum ReadingMode: String, CaseIterable {
        case normal = "普通"
        case dark = "暗色"
        case sepia = "护眼"
        case eyeCare = "暖光"
    }

    public var currentPage: Int = 1
    public var totalPages: Int = 0
    public var zoomLevel: Double = 1.0          // 1.0 = 100%
    public var zoomMode: ZoomMode = .actual
    public var isFullscreen: Bool = false
    public var readingMode: ReadingMode = .normal
    public var displayMode: DisplayMode = .singleContinuous

    // 供 PDFViewWrapper 持有真实的 PDFView 引用
    public weak var pdfView: PDFView?

    // MARK: - Navigation History（前进/后退）
    private var historyStack: [Int] = []
    private var historyIndex: Int = -1
    private var isNavigatingHistory: Bool = false

    public var canGoBack: Bool { historyIndex > 0 }
    public var canGoForward: Bool { historyIndex < historyStack.count - 1 }

    /// 跳转到指定页（带历史记录），用于目录/书签/搜索等跨页跳转
    public func jumpToPage(_ pageNumber: Int) {
        let docPageCount = pdfView?.document?.pageCount ?? totalPages
        let clamped = max(1, min(pageNumber, docPageCount))
        let previousPage = currentPage

        goToPage(clamped)

        // 记录历史：在 goToPage 成功后才记录，避免 pdfView 为 nil 时历史不同步
        if !isNavigatingHistory, currentPage != previousPage {
            if historyIndex < historyStack.count - 1 {
                historyStack.removeSubrange((historyIndex + 1)...)
            }
            historyStack.append(previousPage)
            historyIndex = historyStack.count - 1
            if historyStack.count > 100 {
                historyStack.removeFirst(historyStack.count - 100)
                historyIndex = historyStack.count - 1
            }
        }
    }

    /// 后退
    public func goBack() {
        guard canGoBack else { return }
        isNavigatingHistory = true
        historyIndex -= 1
        goToPage(historyStack[historyIndex])
        isNavigatingHistory = false
    }

    /// 前进
    public func goForward() {
        guard canGoForward else { return }
        isNavigatingHistory = true
        historyIndex += 1
        goToPage(historyStack[historyIndex])
        isNavigatingHistory = false
    }

    /// 清空历史（打开新文档时调用）
    public func clearHistory() {
        historyStack = []
        historyIndex = -1
    }

    // API-010: 跳转页码（BOUND-010：clamp）
    public func goToPage(_ pageNumber: Int) {
        // 优先使用本实例的 pdfView，否则从全局注册表获取
        let targetPDFView = self.pdfView ?? PDFViewRegistry.shared.currentPDFView
        let doc = self.pdfView?.document ?? PDFViewRegistry.shared.currentDocument

        let docPageCount = doc?.pageCount ?? totalPages

        guard docPageCount > 0 else {
            return
        }

        let clamped = max(1, min(pageNumber, docPageCount))

        guard let pdfView = targetPDFView else {
            // 无 PDFView 时仍更新内部状态，保持 state 一致
            currentPage = clamped
            return
        }

        guard let page = pdfView.document?.page(at: clamped - 1) else {
            currentPage = clamped
            return
        }

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

    /// 切换页面显示模式（单页/双页/连续）
    public func setDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
        guard let pdfView else { return }
        switch mode {
        case .singleContinuous:
            pdfView.displayMode = .singlePageContinuous
        case .single:
            pdfView.displayMode = .singlePage
        case .twoContinuous:
            pdfView.displayMode = .twoUpContinuous
        case .two:
            pdfView.displayMode = .twoUp
        }
    }

    /// 切换阅读模式（暗色/护眼/暖光/普通）
    public func setReadingMode(_ mode: ReadingMode) {
        readingMode = mode
        guard let pdfView else { return }
        switch mode {
        case .normal:
            pdfView.backgroundColor = NSColor.windowBackgroundColor
            removePDFColorFilter()
        case .dark:
            pdfView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            applyPDFColorFilter(invert: true)
        case .sepia:
            pdfView.backgroundColor = NSColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1.0)
            removePDFColorFilter()
        case .eyeCare:
            pdfView.backgroundColor = NSColor(red: 0.95, green: 0.92, blue: 0.82, alpha: 1.0)
            removePDFColorFilter()
        }
    }

    private func applyPDFColorFilter(invert: Bool) {
        guard let pdfView else { return }
        let filter = CIFilter(name: "CIColorInvert")
        // 在 PDFView 的 layer 上应用滤镜
        if invert {
            pdfView.layer?.filters = [filter].compactMap { $0 }
        }
    }

    private func removePDFColorFilter() {
        pdfView?.layer?.filters = nil
    }

    /// 键盘滚动一页（Space/Arrow/PageDown/PageUp）
    public func scrollPage(forward: Bool) {
        guard let pdfView else { return }
        if forward {
            pdfView.goToNextPage(nil)
        } else {
            pdfView.goToPreviousPage(nil)
        }
        if let page = pdfView.currentPage {
            currentPage = (pdfView.document?.index(for: page) ?? 0) + 1
        }
    }

    // API-012: 全屏切换
    public func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
        isFullscreen.toggle()
    }

    /// 打印当前文档
    public func printDocument() {
        guard let pdfView else { return }
        pdfView.printView(nil)
    }

    // 由 PDFViewWrapper Coordinator 回调，同步当前页码
    public func updateCurrentPage(_ page: Int) {
        currentPage = page
    }
}
