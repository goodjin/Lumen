import PDFKit

public class SearchService {
    // API-030
    public func search(keyword: String, in document: PDFDocument, caseSensitive: Bool = false) -> [PDFSelection] {
        let truncated = String(keyword.prefix(100))  // BOUND-050
        guard !truncated.isEmpty else { return [] }
        var options: NSString.CompareOptions = []
        if !caseSensitive { options.insert(.caseInsensitive) }
        return document.findString(truncated, withOptions: options)
    }

    public func isSearchable(_ document: PDFDocument) -> Bool {
        // 检查 PDF 是否含有可搜索文本（BOUND-051）
        guard let text = document.string else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
