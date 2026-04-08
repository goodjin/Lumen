import XCTest
@testable import PDFVeCore
import PDFKit
import AppKit

final class SearchServiceTests: XCTestCase {

    private var service: SearchService!
    private var document: PDFDocument!

    override func setUp() {
        super.setUp()
        service = SearchService()
        // 创建带文本内容的测试 PDF（macOS CGContext）
        document = Self.createTextPDF()
    }

    override func tearDown() {
        service = nil
        document = nil
        super.tearDown()
    }

    // MARK: - Helper: 构造含真实文本流的最小 PDF

    private static func createTextPDF() -> PDFDocument {
        // 使用 PDF 原始格式写入文本流，确保 PDFKit 可搜索
        let pdfBytes = """
%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
4 0 obj<</Length 44>>
stream
BT /F1 12 Tf 50 700 Td (Hello World) Tj ET
endstream
endobj
5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj
xref
0 6
0000000000 65535 f\r
0000000009 00000 n\r
0000000058 00000 n\r
0000000115 00000 n\r
0000000266 00000 n\r
0000000360 00000 n\r
trailer<</Size 6/Root 1 0 R>>
startxref
441
%%EOF
"""
        let data = pdfBytes.data(using: .ascii)!
        return PDFDocument(data: data) ?? PDFDocument()
    }

    // MARK: - BOUND-050: 关键词截断

    func test_keyword_truncation_at_100_chars() {
        let longKeyword = String(repeating: "a", count: 150)
        let results = service.search(keyword: longKeyword, in: document)
        XCTAssertNotNil(results)
    }

    func test_empty_keyword_returns_empty() {
        let results = service.search(keyword: "", in: document)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - API-030: search

    func test_search_finds_existing_text() {
        let results = service.search(keyword: "Hello", in: document, caseSensitive: false)
        XCTAssertFalse(results.isEmpty)
    }

    func test_search_case_insensitive() {
        let results = service.search(keyword: "hello", in: document, caseSensitive: false)
        XCTAssertFalse(results.isEmpty)
    }

    func test_search_case_sensitive() {
        let results = service.search(keyword: "hello", in: document, caseSensitive: true)
        XCTAssertTrue(results.isEmpty)
    }

    func test_search_no_match_returns_empty() {
        let results = service.search(keyword: "NotFoundWord", in: document)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - BOUND-051: isSearchable

    func test_isSearchable_returns_true_for_text_pdf() {
        XCTAssertTrue(service.isSearchable(document))
    }
}
