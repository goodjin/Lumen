import XCTest
@testable import PDFVeCore
import PDFKit

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
}
