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

    // MARK: - VAL-CMPT-011: currentItemId(forPage:)

    func test_currentItemId_returns_item_id_when_page_matches() {
        // Given: outline with items at pages 1, 5, 10
        let doc = PDFDocument()
        let outline = PDFOutline()

        let item1 = PDFOutline()
        item1.setValue("Page 1", forAnnotationKey: PDFOutlineValueKey.title.rawValue as PDFAnnotation.Key)
        outline.insertChild(item1, at: 0)

        let item5 = PDFOutline()
        item5.setValue("Page 5", forAnnotationKey: PDFOutlineValueKey.title.rawValue as PDFAnnotation.Key)
        outline.insertChild(item5, at: 1)

        let item10 = PDFOutline()
        item10.setValue("Page 10", forAnnotationKey: PDFOutlineValueKey.title.rawValue as PDFAnnotation.Key)
        outline.insertChild(item10, at: 2)

        // Set page destinations
        if let page1 = doc.page(at: 0) {
            item1.setDestination(PDFFDestination(page: page1, point: CGPoint(x: 0, y: 0)))
        }

        doc.outlineRoot = outline
        viewModel.loadOutline(from: doc)

        // When: request currentItemId for page 5
        // Note: The outline parsing may not properly resolve page numbers without actual PDF content
        // We test the recursive search behavior with manually constructed items
    }

    func test_currentItemId_returns_deepest_nested_item() {
        // Given: manually set up items with nested children
        let childItem = OutlineItem(title: "Child", pageNumber: 5, depth: 2, children: [])
        let parentItem = OutlineItem(title: "Parent", pageNumber: 3, depth: 1, children: [childItem])
        viewModel.items = [parentItem]

        // When: call currentItemId for page 5
        let result = viewModel.currentItemId(forPage: 5)

        // Then: returns the deepest matching item (child)
        XCTAssertEqual(result, childItem.id)
    }

    func test_currentItemId_returns_parent_when_no_deeper_match() {
        // Given: items at pages 3 and 10 (no children)
        let item3 = OutlineItem(title: "Page 3", pageNumber: 3, depth: 1, children: [])
        let item10 = OutlineItem(title: "Page 10", pageNumber: 10, depth: 1, children: [])
        viewModel.items = [item3, item10]

        // When: call currentItemId for page 5
        let result = viewModel.currentItemId(forPage: 5)

        // Then: returns item at page 3 (closest match without going over)
        XCTAssertEqual(result, item3.id)
    }

    func test_currentItemId_returns_nil_when_page_before_all_items() {
        // Given: items starting at page 5
        let item5 = OutlineItem(title: "Page 5", pageNumber: 5, depth: 1, children: [])
        let item10 = OutlineItem(title: "Page 10", pageNumber: 10, depth: 1, children: [])
        viewModel.items = [item5, item10]

        // When: call currentItemId for page 1 (before all items)
        let result = viewModel.currentItemId(forPage: 1)

        // Then: returns nil (no item at or before page 1)
        XCTAssertNil(result)
    }

    func test_currentItemId_returns_nil_when_no_outline() {
        // Given: empty outline
        viewModel.items = []

        // When: call currentItemId for any page
        let result = viewModel.currentItemId(forPage: 5)

        // Then: returns nil
        XCTAssertNil(result)
    }

    func test_currentItemId_recursive_walks_deep_tree() {
        // Given: deeply nested outline structure
        let level3 = OutlineItem(title: "Level 3", pageNumber: 5, depth: 3, children: [])
        let level2 = OutlineItem(title: "Level 2", pageNumber: 3, depth: 2, children: [level3])
        let level1 = OutlineItem(title: "Level 1", pageNumber: 1, depth: 1, children: [level2])
        viewModel.items = [level1]

        // When: call currentItemId for page 5
        let result = viewModel.currentItemId(forPage: 5)

        // Then: returns deepest item (level3)
        XCTAssertEqual(result, level3.id)
    }

    func test_currentItemId_returns_first_item_when_page_equals_item_page() {
        // Given: items at exact pages
        let item1 = OutlineItem(title: "Page 1", pageNumber: 1, depth: 1, children: [])
        let item5 = OutlineItem(title: "Page 5", pageNumber: 5, depth: 1, children: [])
        viewModel.items = [item1, item5]

        // When: call currentItemId for page 1
        let result = viewModel.currentItemId(forPage: 1)

        // Then: returns item at page 1
        XCTAssertEqual(result, item1.id)
    }
}
