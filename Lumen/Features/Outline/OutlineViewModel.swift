import PDFKit
import SwiftUI

@MainActor
@Observable
public class OutlineViewModel {
    public init() {}
    public var items: [OutlineItem] = []
    public var hasOutline: Bool = false

    // API-020：加载目录（最多 5 级）
    public func loadOutline(from document: PDFDocument) {
        guard let root = document.outlineRoot else {
            hasOutline = false
            items = []
            return
        }
        hasOutline = true
        items = parseOutline(root, document: document, depth: 1)
    }

    private func parseOutline(_ outline: PDFOutline, document: PDFDocument, depth: Int) -> [OutlineItem] {
        guard depth <= 5 else { return [] }   // 最多 5 级（AC-004-03）
        var result: [OutlineItem] = []
        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }
            let pageNum: Int
            if let page = child.destination?.page {
                pageNum = document.index(for: page) + 1
            } else {
                pageNum = 1
            }
            let children = parseOutline(child, document: document, depth: depth + 1)
            let item = OutlineItem(
                title: child.label ?? "（无标题）",
                pageNumber: pageNum,
                depth: depth,
                children: children
            )
            result.append(item)
        }
        return result
    }

    // API-021：点击目录项，通知 ReaderViewModel 跳转
    public func selectItem(_ item: OutlineItem, readerVM: ReaderViewModel) {
        readerVM.goToPage(item.pageNumber)
    }
}
