import PDFKit
import SwiftUI

@MainActor
@Observable
public class SearchViewModel {
    public init() {}
    private let service = SearchService()

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
    }

    private func highlight(_ selection: PDFSelection) {
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.scrollSelectionToVisible(nil)
    }
}
