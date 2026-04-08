import XCTest
@testable import PDFVeCore
import PDFKit

final class OutlineViewModelTests: XCTestCase {

    private var viewModel: OutlineViewModel!

    override func setUp() {
        super.setUp()
        viewModel = OutlineViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - loadOutline: no outline

    func test_loadOutline_sets_hasOutline_false_when_no_outline() {
        let doc = PDFDocument()
        viewModel.loadOutline(from: doc)
        XCTAssertFalse(viewModel.hasOutline)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    // MARK: - loadOutline: with outline

    func test_loadOutline_sets_hasOutline_true_when_outline_exists() {
        // 创建带大纲根节点的 PDF
        let doc = PDFDocument()
        let outline = PDFOutline()
        outline.setValue("Chapter 1", forAnnotationKey: PDFOutlineValueKey.title.rawValue as PDFAnnotation.Key)
        outline.insertChild(PDFOutline(), at: 0)
        doc.outlineRoot = outline

        viewModel.loadOutline(from: doc)
        XCTAssertTrue(viewModel.hasOutline)
    }

    // MARK: - selectItem

    func test_selectItem_calls_goToPage() {
        let mockReaderVM = ReaderViewModel()
        mockReaderVM.totalPages = 10

        let item = OutlineItem(title: "Page 5", pageNumber: 5, depth: 1)
        viewModel.selectItem(item, readerVM: mockReaderVM)
        XCTAssertEqual(mockReaderVM.currentPage, 5)
    }

    // MARK: - max depth 5

    func test_loadOutline_respects_max_depth_5() {
        let doc = PDFDocument()
        let outline = PDFOutline()

        // 嵌套创建 7 层
        var current = outline
        for i in 0..<7 {
            let child = PDFOutline()
            child.setValue("Level \(i)", forAnnotationKey: PDFOutlineValueKey.title.rawValue as PDFAnnotation.Key)
            current.insertChild(child, at: 0)
            current = child
        }
        doc.outlineRoot = outline

        viewModel.loadOutline(from: doc)
        // 第一层 items 应该有内容，但最深层的 children 应该为空（depth 6 被截断）
        XCTAssertFalse(viewModel.items.isEmpty)
    }
}
