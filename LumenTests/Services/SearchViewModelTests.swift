import XCTest
@testable import PDFVeCore
import PDFKit
import AppKit

@MainActor
final class SearchViewModelTests: XCTestCase {

    private var viewModel: SearchViewModel!
    private var textDocument: PDFDocument!
    private var imageDocument: PDFDocument!

    override func setUp() {
        super.setUp()
        viewModel = SearchViewModel()
        textDocument = createTextPDF()
        imageDocument = createImagePDF()
    }

    override func tearDown() {
        viewModel = nil
        textDocument = nil
        imageDocument = nil
        super.tearDown()
    }

    // MARK: - Helper: Create Test PDFs

    /// PDF containing "Hello World" text — searchable with both case-sensitive and case-insensitive search
    private func createTextPDF() -> PDFDocument? {
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
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000266 00000 n 
0000000360 00000 n 
trailer<</Size 6/Root 1 0 R>>
startxref
441
%%EOF
"""
        return PDFDocument(data: pdfBytes.data(using: .ascii)!)
    }

    /// PDF with no searchable text — only graphics
    private func createImagePDF() -> PDFDocument? {
        let pdfBytes = """
%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<<>>>>endobj
4 0 obj<</Length 14>>
stream
1 0 0 rg
0 0 m
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000248 00000 n 
trailer<</Size 5/Root 1 0 R>>
startxref
312
%%EOF
"""
        return PDFDocument(data: pdfBytes.data(using: .ascii)!)
    }

    // MARK: - VAL-CMPT-007: Debounce

    func test_debouncedSearch_fires_after_300ms() async {
        // Arrange
        viewModel.keyword = "Hello"
        let expectation = XCTestExpectation(description: "search fires after 300ms")
        expectation.isInverted = true // Will fulfill immediately if not cancelled

        // Act: call debouncedSearch
        viewModel.debouncedSearch(in: textDocument!)

        // Assert: before 300ms, results should be empty (search not yet fired)
        XCTAssertTrue(viewModel.results.isEmpty)

        // Wait for debounce delay + buffer
        try? await Task.sleep(nanoseconds: 350_000_000)

        // Assert: after 300ms, results should contain matches
        XCTAssertFalse(viewModel.results.isEmpty)
    }

    func test_debouncedSearch_empty_keyword_clears_results_immediately() {
        // Arrange: first populate results with a search
        viewModel.keyword = "Hello"
        viewModel.performSearch(in: textDocument!)
        XCTAssertFalse(viewModel.results.isEmpty)

        // Act: clear keyword (triggers immediate clear, not debounced)
        viewModel.keyword = ""
        viewModel.debouncedSearch(in: textDocument!)

        // Assert: results cleared immediately (not after 300ms)
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertEqual(viewModel.currentIndex, 0)
    }

    func test_debouncedSearch_cancels_inflight_search_on_new_keystroke() async {
        // Arrange: start first search with "Hello"
        viewModel.keyword = "Hello"
        viewModel.debouncedSearch(in: textDocument!)

        // Act: before 300ms fires, start another search with "World"
        try? await Task.sleep(nanoseconds: 100_000_000) // wait 100ms
        viewModel.keyword = "World"
        viewModel.debouncedSearch(in: textDocument!)

        // Wait for second debounce to complete
        try? await Task.sleep(nanoseconds: 350_000_000)

        // Assert: results contain "World" matches, not "Hello"
        XCTAssertFalse(viewModel.results.isEmpty)
        // The search that ran was for "World", not "Hello"
        // We verify by checking the selection string
        if let firstResult = viewModel.results.first {
            XCTAssertTrue(firstResult.string?.contains("World") ?? false)
        }
    }

    // MARK: - VAL-CMPT-008: Case Sensitivity

    func test_performSearch_caseSensitive_true_finds_exact_match_only() {
        // Arrange
        viewModel.caseSensitive = true
        viewModel.keyword = "hello" // lowercase

        // Act
        viewModel.performSearch(in: textDocument!)

        // Assert: lowercase "hello" should NOT match "Hello" (case sensitive)
        XCTAssertTrue(viewModel.results.isEmpty)
    }

    func test_performSearch_caseSensitive_false_finds_case_insensitive_match() {
        // Arrange
        viewModel.caseSensitive = false
        viewModel.keyword = "hello" // lowercase

        // Act
        viewModel.performSearch(in: textDocument!)

        // Assert: lowercase "hello" SHOULD match "Hello" (case insensitive)
        XCTAssertFalse(viewModel.results.isEmpty)
    }

    func test_performSearch_caseSensitive_true_finds_exact_case() {
        // Arrange
        viewModel.caseSensitive = true
        viewModel.keyword = "Hello" // exact case

        // Act
        viewModel.performSearch(in: textDocument!)

        // Assert: "Hello" matches "Hello" exactly
        XCTAssertFalse(viewModel.results.isEmpty)
    }

    // MARK: - dismissSearch clears results

    func test_dismissSearch_clears_results() {
        // Arrange: perform a search first
        viewModel.keyword = "Hello"
        viewModel.performSearch(in: textDocument!)
        XCTAssertFalse(viewModel.results.isEmpty)

        // Act
        viewModel.dismissSearch()

        // Assert
        XCTAssertTrue(viewModel.results.isEmpty)
    }

    func test_dismissSearch_clears_keyword() {
        // Arrange
        viewModel.keyword = "Hello"
        viewModel.performSearch(in: textDocument!)

        // Act
        viewModel.dismissSearch()

        // Assert
        XCTAssertEqual(viewModel.keyword, "")
    }

    func test_dismissSearch_hides_search_bar() {
        // Arrange
        viewModel.isSearchBarVisible = true

        // Act
        viewModel.dismissSearch()

        // Assert
        XCTAssertFalse(viewModel.isSearchBarVisible)
    }
}
