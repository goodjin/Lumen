import PDFKit
import SwiftUI

@MainActor
@Observable
public class SearchViewModel {
    public init() {
        // Listen for showSearchBar notification (triggered by --show-search launch argument)
        NotificationCenter.default.addObserver(
            forName: Notification.Name("showSearchBar"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSearchBarVisible = true
        }
        // Also check --show-search flag directly in case notification was posted before init
        if ProcessInfo.processInfo.arguments.contains("--show-search") {
            isSearchBarVisible = true
        }
        // Note: setSearchKeyword notification is NOT handled here to avoid race conditions.
        // Search is triggered by:
        //   - SearchBarView.onChange(of: searchVM.keyword) calling debouncedSearch → performSearch
        //   - MainWindowView.handleDocumentLoaded calling performSearch directly (UITesting)
    }
    private let service = SearchService()
    private var searchTask: Task<Void, Never>?
    private var documentRef: PDFDocument?

    public var keyword: String = ""
    public var results: [PDFSelection] = []
    public var currentIndex: Int = 0
    public var isSearchBarVisible: Bool = false
    public var caseSensitive: Bool = false
    public var isUnsearchable: Bool = false  // BOUND-051

    public var hasNoResults: Bool { !keyword.isEmpty && results.isEmpty && !isUnsearchable }
    public var resultSummary: String {
        guard !results.isEmpty else { return "" }
        return "\(currentIndex + 1)/\(results.count)"
    }

    // 供 PDFViewWrapper 持有引用以高亮结果
    public weak var pdfView: PDFView?

    /// 带 300ms 防抖的搜索入口（绑定 keyword onChange 调用）
    public func debouncedSearch(in document: PDFDocument) {
        documentRef = document
        searchTask?.cancel()
        guard !keyword.isEmpty else {
            results = []
            currentIndex = 0
            isUnsearchable = false
            pdfView?.clearSelection()
            pdfView?.highlightedSelections = nil
            return
        }
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            performSearch(in: document)
        }
    }

    public func performSearch(in document: PDFDocument) {
        // BOUND-051：检查可搜索性
        if !service.isSearchable(document) {
            isUnsearchable = true
            results = []
            return
        }
        isUnsearchable = false
        results = service.search(keyword: keyword, in: document, caseSensitive: caseSensitive)
        currentIndex = 0
        if let first = results.first {
            pdfView?.setCurrentSelection(first, animate: true)
            pdfView?.scrollSelectionToVisible(nil)
        }
        // Highlight all matches simultaneously
        highlightAllMatches()
    }

    // API-031
    public func nextMatch() {
        guard !results.isEmpty else { return }
        currentIndex = (currentIndex + 1) % results.count
        highlight(results[currentIndex])
    }

    // API-032
    public func previousMatch() {
        guard !results.isEmpty else { return }
        currentIndex = (currentIndex - 1 + results.count) % results.count
        highlight(results[currentIndex])
    }

    // API-033
    public func dismissSearch() {
        isSearchBarVisible = false
        keyword = ""
        results = []
        currentIndex = 0
        isUnsearchable = false
        pdfView?.clearSelection()
        pdfView?.highlightedSelections = nil
    }

    private func highlight(_ selection: PDFSelection) {
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.scrollSelectionToVisible(nil)
    }

    /// Highlight all search matches simultaneously using PDFView.highlightedSelections
    /// Current match gets orange highlight (via currentSelection), others get yellow
    private func highlightAllMatches() {
        pdfView?.highlightedSelections = results
    }
}
