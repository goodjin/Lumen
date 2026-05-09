import XCTest
@testable import PDFVeCore
import SwiftData
import PDFKit

@MainActor
final class SidebarViewModelTests: XCTestCase {

    private var sidebarVM: SidebarViewModel!
    private var annotationVM: AnnotationViewModel!
    private var readerVM: ReaderViewModel!
    private var bookmarkRepo: BookmarkRepository!
    private var annotationRepo: AnnotationRepository!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        // Setup in-memory SwiftData container
        let schema = Schema([AnnotationRecord.self, BookmarkRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)

        annotationRepo = AnnotationRepository(context: container.mainContext)
        let annotationService = AnnotationService(repo: annotationRepo)

        bookmarkRepo = BookmarkRepository(context: container.mainContext)
        let bookmarkService = BookmarkService(repository: bookmarkRepo)

        annotationVM = AnnotationViewModel(service: annotationService, repo: annotationRepo)
        annotationVM.documentPath = "/tmp/test.pdf"

        readerVM = ReaderViewModel()
        readerVM.totalPages = 10
        readerVM.currentPage = 1

        sidebarVM = SidebarViewModel(
            bookmarkService: bookmarkService,
            readerVM: readerVM,
            annotationVM: annotationVM
        )
        sidebarVM.documentPath = "/tmp/test.pdf"
    }

    override func tearDown() {
        sidebarVM = nil
        annotationVM = nil
        readerVM = nil
        bookmarkRepo = nil
        annotationRepo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - VAL-CMPT-010: filteredAnnotations()

    func test_filteredAnnotations_with_nil_filter_returns_all_annotations() {
        // Given: load annotations and set nil filter (show all)
        annotationVM.loadAnnotations(for: annotationVM.documentPath)
        sidebarVM.annotationFilter = nil

        // Create one of each annotation type
        let pdf = createTestPDF()
        guard let selection = createSelection(in: pdf) else { XCTFail("Could not create selection"); return }
        annotationVM.createTextAnnotation(type: .highlight, selection: selection, color: .yellow)
        _ = annotationVM.createNote(at: CGPoint(x: 50, y: 50), pageNumber: 1)
        let path = [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)]
        annotationVM.finishDrawing(path: path, color: .red, lineWidth: .medium, pageNumber: 1)

        // When: call filteredAnnotations
        let result = sidebarVM.filteredAnnotations()

        // Then: all 3 annotations returned
        XCTAssertEqual(result.count, 3)
    }

    func test_filteredAnnotations_with_highlight_filter_returns_only_highlights() {
        // Given: load annotations and set highlight filter
        annotationVM.loadAnnotations(for: annotationVM.documentPath)
        sidebarVM.annotationFilter = .highlight

        // Create mixed annotation types
        let pdf = createTestPDF()
        guard let selection = createSelection(in: pdf) else { XCTFail("Could not create selection"); return }
        annotationVM.createTextAnnotation(type: .highlight, selection: selection, color: .yellow)
        _ = annotationVM.createNote(at: CGPoint(x: 50, y: 50), pageNumber: 1)
        let path = [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)]
        annotationVM.finishDrawing(path: path, color: .red, lineWidth: .medium, pageNumber: 1)

        // When: call filteredAnnotations
        let result = sidebarVM.filteredAnnotations()

        // Then: only 1 highlight annotation returned
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.annotationType, .highlight)
    }

    func test_filteredAnnotations_with_note_filter_returns_only_notes() {
        // Given: set note filter
        annotationVM.loadAnnotations(for: annotationVM.documentPath)
        sidebarVM.annotationFilter = .note

        // Create mixed annotation types
        let pdf = createTestPDF()
        guard let selection = createSelection(in: pdf) else { XCTFail("Could not create selection"); return }
        annotationVM.createTextAnnotation(type: .highlight, selection: selection, color: .yellow)
        _ = annotationVM.createNote(at: CGPoint(x: 50, y: 50), pageNumber: 1)

        // When: call filteredAnnotations
        let result = sidebarVM.filteredAnnotations()

        // Then: only 1 note annotation returned
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.annotationType, .note)
    }

    func test_filteredAnnotations_with_drawing_filter_returns_only_drawings() {
        // Given: set drawing filter
        annotationVM.loadAnnotations(for: annotationVM.documentPath)
        sidebarVM.annotationFilter = .drawing

        // Create mixed annotation types
        let pdf = createTestPDF()
        guard let selection = createSelection(in: pdf) else { XCTFail("Could not create selection"); return }
        annotationVM.createTextAnnotation(type: .highlight, selection: selection, color: .yellow)
        let path = [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)]
        annotationVM.finishDrawing(path: path, color: .red, lineWidth: .medium, pageNumber: 1)

        // When: call filteredAnnotations
        let result = sidebarVM.filteredAnnotations()

        // Then: only 1 drawing annotation returned
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.annotationType, .drawing)
    }

    func test_filteredAnnotations_with_underline_filter_returns_only_underlines() {
        // Given: set underline filter
        annotationVM.loadAnnotations(for: annotationVM.documentPath)
        sidebarVM.annotationFilter = .underline

        // Create underline annotation
        let pdf = createTestPDF()
        guard let selection = createSelection(in: pdf) else { XCTFail("Could not create selection"); return }
        annotationVM.createTextAnnotation(type: .underline, selection: selection, color: .green)

        // When: call filteredAnnotations
        let result = sidebarVM.filteredAnnotations()

        // Then: only 1 underline annotation returned
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.annotationType, .underline)
    }

    func test_filteredAnnotations_with_strikethrough_filter_returns_only_strikethroughs() {
        // Given: set strikethrough filter
        annotationVM.loadAnnotations(for: annotationVM.documentPath)
        sidebarVM.annotationFilter = .strikethrough

        // Create strikethrough annotation
        let pdf = createTestPDF()
        guard let selection = createSelection(in: pdf) else { XCTFail("Could not create selection"); return }
        annotationVM.createTextAnnotation(type: .strikethrough, selection: selection, color: .blue)

        // When: call filteredAnnotations
        let result = sidebarVM.filteredAnnotations()

        // Then: only 1 strikethrough annotation returned
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.annotationType, .strikethrough)
    }

    func test_filteredAnnotations_with_empty_filter_returns_all() {
        // Given: empty annotations list with nil filter
        annotationVM.loadAnnotations(for: annotationVM.documentPath)
        sidebarVM.annotationFilter = nil

        // When: call filteredAnnotations with no annotations
        let result = sidebarVM.filteredAnnotations()

        // Then: empty array returned
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Helper methods

    private func createTestPDF() -> PDFDocument {
        let pdfData = Data("%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n4 0 obj<</Length 44>>\nstream\nBT /F1 12 Tf 50 700 Td (Test) Tj ET\nendstream\nendobj\n5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\nxref\n0 6\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000267 00000 n \n0000000361 00000 n \ntrailer<</Size 6/Root 1 0 R>>\nstartxref\n456\n%%EOF\n".utf8)
        return PDFDocument(data: pdfData)!
    }

    private func createSelection(in document: PDFDocument) -> PDFSelection? {
        let selections = document.findString("Test", withOptions: .caseInsensitive)
        return selections.first
    }
}
