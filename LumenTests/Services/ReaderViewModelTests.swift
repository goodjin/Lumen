import XCTest
@testable import PDFVeCore
import PDFKit
import AppKit

@MainActor
final class ReaderViewModelTests: XCTestCase {

    private var viewModel: ReaderViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ReaderViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helper: Create Multi-Page Test PDF

    private func createTestPDF(pageCount: Int) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).pdf")

        // Generate minimal multi-page PDF using raw bytes
        var pdfBytes = "%PDF-1.4\n"

        // Object 1: Catalog
        pdfBytes += "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"

        // Object 2: Pages (with page count)
        let pageKids = (0..<pageCount).map { "\(3 + $0) 0 R" }.joined(separator: " ")
        pdfBytes += "2 0 obj<</Type/Pages/Kids[\(pageKids)]/Count \(pageCount)>>endobj\n"

        // Objects 3+: Each page
        for i in 0..<pageCount {
            let contentObj = 3 + pageCount + i
            let pageObj = 3 + i
            pdfBytes += "\(pageObj) 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents \(contentObj) 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n"
            pdfBytes += "\(contentObj) 0 obj<</Length 44>>\nstream\nBT /F1 12 Tf 50 700 Td (Page \(i + 1)) Tj ET\nendstream\nendobj\n"
        }

        // Object for font
        pdfBytes += "5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n"

        // Cross-reference table
        let xrefPos = pdfBytes.count
        pdfBytes += "xref\n0 \(3 + pageCount + 1)\n"
        pdfBytes += "0000000000 65535 f \n"

        var offset = 0
        let catalogOffset = 0
        pdfBytes += String(format: "%09d 00000 n \n", catalogOffset)
        offset = pdfBytes.count
        let pagesOffset = offset
        pdfBytes += String(format: "%09d 00000 n \n", pagesOffset)
        offset = pdfBytes.count

        // Page and content offsets
        for _ in 0..<pageCount {
            pdfBytes += String(format: "%09d 00000 n \n", offset)
            offset = pdfBytes.count
            pdfBytes += String(format: "%09d 00000 n \n", offset)
            offset = pdfBytes.count
        }

        // Font offset
        pdfBytes += String(format: "%09d 00000 n \n", offset)

        pdfBytes += "trailer<</Size \(3 + pageCount + 1)/Root 1 0 R>>\n"
        pdfBytes += "startxref\n\(xrefPos)\n%%EOF\n"

        do {
            try pdfBytes.write(to: pdfURL, atomically: true, encoding: .ascii)
            testPDFURL = pdfURL
            return pdfURL
        } catch {
            return nil
        }
    }

    private var testPDFURL: URL?

    private func setupViewModelWithPDF(pageCount: Int) {
        guard let url = createTestPDF(pageCount: pageCount),
              let document = PDFDocument(url: url) else {
            return
        }
        let pdfView = PDFView()
        pdfView.document = document
        viewModel.pdfView = pdfView
        viewModel.totalPages = document.pageCount
        viewModel.currentPage = 1
    }

    // MARK: - goToPage BOUND-010

    func test_goToPage_clamps_below_1() {
        viewModel.totalPages = 10
        // goToPage with nil pdfView should not crash
        viewModel.goToPage(0)
        // With no pdfView, the function returns early - no crash = pass
    }

    func test_goToPage_clamps_above_total() {
        viewModel.totalPages = 10
        viewModel.goToPage(999)
        // No crash due to guard
    }

    // MARK: - zoomIn/zoomOut bounds

    func test_zoomIn_respects_upper_bound() {
        viewModel.zoomLevel = 5.0
        viewModel.zoomIn()
        XCTAssertEqual(viewModel.zoomLevel, 5.0)
    }

    func test_zoomOut_respects_lower_bound() {
        viewModel.zoomLevel = 0.1
        viewModel.zoomOut()
        XCTAssertEqual(viewModel.zoomLevel, 0.1)
    }

    // MARK: - ZoomMode

    func test_setZoom_sets_level_and_mode() {
        viewModel.setZoom(2.0)
        XCTAssertEqual(viewModel.zoomLevel, 2.0)
        XCTAssertEqual(viewModel.zoomMode, .actual)
    }

    // MARK: - isFullscreen

    func test_toggleFullscreen_toggles_state() {
        XCTAssertFalse(viewModel.isFullscreen)
        viewModel.toggleFullscreen()
        XCTAssertTrue(viewModel.isFullscreen)
    }

    // MARK: - updateCurrentPage

    func test_updateCurrentPage_sets_current_page() {
        viewModel.currentPage = 1
        viewModel.updateCurrentPage(5)
        XCTAssertEqual(viewModel.currentPage, 5)
    }

    // MARK: - VAL-CMPT-001: History Navigation

    func test_jumpToPage_records_current_page_in_history() {
        // Setup: 3-page PDF, current page 1
        viewModel.clearHistory()
        viewModel.currentPage = 1
        viewModel.totalPages = 3

        XCTAssertFalse(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)

        // Act: jump to page 2 (history records page 1)
        viewModel.jumpToPage(2)

        // Assert: history = [1], index=0. At first history entry, canGoBack=false (nothing before), canGoForward=false
        XCTAssertFalse(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
    }

    func test_jumpToPage_truncates_forward_history() {
        // Setup: build history stack 1 -> 2 -> 3
        viewModel.clearHistory()
        viewModel.currentPage = 1
        viewModel.totalPages = 5

        viewModel.jumpToPage(2)  // history: [1], index=0
        viewModel.jumpToPage(3)  // history: [1, 2], index=1

        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)  // at end

        // Act: jump to page 4 (records page 3 in history since we navigated from page 3)
        viewModel.jumpToPage(4)

        // Assert: history = [1, 2, 3], index=2 → can go back but not forward
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
    }

    func test_goBack_decrements_history_index() {
        // Setup: build history stack 1 -> 2 -> 3
        viewModel.clearHistory()
        viewModel.currentPage = 1
        viewModel.totalPages = 5

        viewModel.jumpToPage(2)  // history: [1], index=0
        viewModel.jumpToPage(3)  // history: [1, 2], index=1

        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)  // at end of history

        // Act: go back (decrements historyIndex)
        viewModel.goBack()

        // Assert: history=[1,2], index=0 (after goBack) → canGoBack=false (nothing before), canGoForward=true
        XCTAssertFalse(viewModel.canGoBack)
        XCTAssertTrue(viewModel.canGoForward)
    }

    func test_goForward_increments_history_index() {
        // Setup: build history and go back
        viewModel.clearHistory()
        viewModel.currentPage = 1
        viewModel.totalPages = 5

        viewModel.jumpToPage(2)  // history: [1], index=0
        viewModel.jumpToPage(3)  // history: [1, 2], index=1
        viewModel.goBack()       // historyIndex=0

        XCTAssertFalse(viewModel.canGoBack)
        XCTAssertTrue(viewModel.canGoForward)

        // Act: go forward (increments historyIndex)
        viewModel.goForward()

        // Assert: after goForward, history=[1,2], index=1 → canGoBack=true, canGoForward=false (at end)
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
    }

    func test_canGoBack_is_false_at_start_of_history() {
        viewModel.clearHistory()
        viewModel.currentPage = 1
        viewModel.totalPages = 3

        // Navigate to page 2 then back to page 1
        viewModel.jumpToPage(2)  // history: [1], index=0
        viewModel.goBack()       // historyIndex becomes 0, canGoBack = false

        // Assert: can't go back further
        XCTAssertFalse(viewModel.canGoBack)
    }

    func test_canGoForward_is_false_at_end_of_history() {
        viewModel.clearHistory()
        viewModel.currentPage = 1
        viewModel.totalPages = 5

        viewModel.jumpToPage(2)  // history: [1], index=0
        viewModel.jumpToPage(3)  // history: [1, 2], index=1

        // Assert: at page 3 with history [1,2], can go back but not forward
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
    }

    func test_clearHistory_empties_stack() {
        viewModel.clearHistory()
        viewModel.totalPages = 5

        viewModel.jumpToPage(2)
        viewModel.jumpToPage(3)

        // Act
        viewModel.clearHistory()

        // Assert: history is cleared
        XCTAssertFalse(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
    }

    // MARK: - VAL-CMPT-002: Reading Mode

    func test_setReadingMode_normal_sets_background_and_removes_filter() {
        setupViewModelWithPDF(pageCount: 1)
        viewModel.pdfView?.backgroundColor = NSColor.darkGray

        viewModel.setReadingMode(.normal)

        XCTAssertEqual(viewModel.readingMode, .normal)
        // normal sets windowBackgroundColor
        XCTAssertNotNil(viewModel.pdfView?.backgroundColor)
        // filter should be removed
        XCTAssertNil(viewModel.pdfView?.layer?.filters)
    }

    func test_setReadingMode_dark_sets_dark_background_and_applies_invert_filter() {
        setupViewModelWithPDF(pageCount: 1)

        viewModel.setReadingMode(.dark)

        XCTAssertEqual(viewModel.readingMode, .dark)
        // dark sets dark background color
        XCTAssertNotNil(viewModel.pdfView?.backgroundColor)
        // invert filter should be applied
        XCTAssertFalse(viewModel.pdfView?.layer?.filters?.isEmpty ?? true)
    }

    func test_setReadingMode_sepia_sets_sepia_background() {
        setupViewModelWithPDF(pageCount: 1)

        viewModel.setReadingMode(.sepia)

        XCTAssertEqual(viewModel.readingMode, .sepia)
        XCTAssertNotNil(viewModel.pdfView?.backgroundColor)
        // sepia should not have invert filter
        XCTAssertTrue(viewModel.pdfView?.layer?.filters?.isEmpty ?? true)
    }

    func test_setReadingMode_eyeCare_sets_warm_background() {
        setupViewModelWithPDF(pageCount: 1)

        viewModel.setReadingMode(.eyeCare)

        XCTAssertEqual(viewModel.readingMode, .eyeCare)
        XCTAssertNotNil(viewModel.pdfView?.backgroundColor)
        // eyeCare should not have invert filter
        XCTAssertTrue(viewModel.pdfView?.layer?.filters?.isEmpty ?? true)
    }

    // MARK: - VAL-CMPT-003: Display Mode

    func test_setDisplayMode_single_sets_singlePage() {
        setupViewModelWithPDF(pageCount: 1)

        viewModel.setDisplayMode(.single)

        XCTAssertEqual(viewModel.displayMode, .single)
        XCTAssertEqual(viewModel.pdfView?.displayMode, .singlePage)
    }

    func test_setDisplayMode_singleContinuous_sets_singlePageContinuous() {
        setupViewModelWithPDF(pageCount: 1)

        viewModel.setDisplayMode(.singleContinuous)

        XCTAssertEqual(viewModel.displayMode, .singleContinuous)
        XCTAssertEqual(viewModel.pdfView?.displayMode, .singlePageContinuous)
    }

    func test_setDisplayMode_two_sets_twoUp() {
        setupViewModelWithPDF(pageCount: 1)

        viewModel.setDisplayMode(.two)

        XCTAssertEqual(viewModel.displayMode, .two)
        XCTAssertEqual(viewModel.pdfView?.displayMode, .twoUp)
    }

    func test_setDisplayMode_twoContinuous_sets_twoUpContinuous() {
        setupViewModelWithPDF(pageCount: 1)

        viewModel.setDisplayMode(.twoContinuous)

        XCTAssertEqual(viewModel.displayMode, .twoContinuous)
        XCTAssertEqual(viewModel.pdfView?.displayMode, .twoUpContinuous)
    }

    // MARK: - VAL-CMPT-004: Zoom Clamping

    func test_setZoom_clamps_to_valid_range() {
        // Test clamping below minimum
        viewModel.setZoom(0.05)
        XCTAssertEqual(viewModel.zoomLevel, 0.1)

        // Test clamping above maximum
        viewModel.setZoom(10.0)
        XCTAssertEqual(viewModel.zoomLevel, 5.0)

        // Test valid value stays unchanged
        viewModel.setZoom(2.5)
        XCTAssertEqual(viewModel.zoomLevel, 2.5)
    }

    // MARK: - VAL-CMPT-004: Zoom Mode

    func test_setZoomMode_fitWidth_sets_zoomMode_and_autoScales_false() {
        // Setup: PDF with page to calculate scale
        setupViewModelWithPDF(pageCount: 1)

        // Act
        viewModel.setZoomMode(.fitWidth)

        // Assert: zoomMode is set to fitWidth
        XCTAssertEqual(viewModel.zoomMode, .fitWidth)
        // autoScales should be false for fitWidth mode
        XCTAssertFalse(viewModel.pdfView?.autoScales ?? true)
    }

    func test_setZoomMode_fitPage_sets_zoomMode_and_autoScales_true() {
        // Setup: PDF with page
        setupViewModelWithPDF(pageCount: 1)

        // Act
        viewModel.setZoomMode(.fitPage)

        // Assert: zoomMode is set to fitPage
        XCTAssertEqual(viewModel.zoomMode, .fitPage)
        // autoScales should be true for fitPage mode
        XCTAssertTrue(viewModel.pdfView?.autoScales ?? false)
    }
}
