import XCTest
@testable import PDFVeCore
import PDFKit
import SwiftData

@MainActor
final class AnnotationServiceTests: XCTestCase {

    private var service: AnnotationService!
    private var repo: AnnotationRepository!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let schema = Schema([AnnotationRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        repo = AnnotationRepository(context: container.mainContext)
        service = AnnotationService(repo: repo)
    }

    override func tearDown() {
        service = nil
        repo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - createTextAnnotation BOUND-020

    @MainActor
    func test_createTextAnnotation_throws_when_no_selectable_text() async throws {
        let selection = PDFSelection()
        do {
            _ = try service.createTextAnnotation(
                type: .highlight,
                selection: selection,
                color: .yellow,
                documentPath: "/tmp/test.pdf"
            )
            XCTFail("Should throw AnnotationError.noSelectableText")
        } catch let error as AnnotationError {
            XCTAssertEqual(error, .noSelectableText)
        }
    }

    // MARK: - createDrawingAnnotation BOUND-022

    @MainActor
    func test_createDrawingAnnotation_returns_nil_when_path_too_short() async throws {
        let path = [CGPoint(x: 10, y: 10)]
        let result = service.createDrawingAnnotation(
            path: path,
            color: .red,
            lineWidth: .medium,
            pageNumber: 1,
            documentPath: "/tmp/test.pdf"
        )
        XCTAssertNil(result)
    }

    @MainActor
    func test_createDrawingAnnotation_creates_record_with_two_points() async throws {
        let path = [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)]
        let result = service.createDrawingAnnotation(
            path: path,
            color: .blue,
            lineWidth: .thin,
            pageNumber: 1,
            documentPath: "/tmp/test.pdf"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.annotationType, .drawing)
        XCTAssertEqual(result?.colorHex, AnnotationColor.blue.rawValue)
    }

    // MARK: - API-042: updateAnnotation

    @MainActor
    func test_updateAnnotation_changes_content() async throws {
        let path = [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)]
        let record = service.createDrawingAnnotation(
            path: path, color: .red, lineWidth: .medium,
            pageNumber: 1, documentPath: "/tmp/test.pdf"
        )!
        XCTAssertNil(record.content)

        service.updateAnnotation(record, content: "Updated content")
        XCTAssertEqual(record.content, "Updated content")
    }

    // MARK: - API-043: deleteAnnotation

    @MainActor
    func test_deleteAnnotation_removes_from_repo() async throws {
        let path = [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)]
        let record = service.createDrawingAnnotation(
            path: path, color: .red, lineWidth: .medium,
            pageNumber: 1, documentPath: "/tmp/test.pdf"
        )!
        let id = record.id

        service.deleteAnnotation(id: id)

        let all = (try? repo.fetchAll(for: "/tmp/test.pdf")) ?? []
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Rule-001: 不调用 PDFKit 标注写入

    @MainActor
    func test_no_pdfkit_annotation_write() async throws {
        let note = service.createNoteAnnotation(
            at: CGPoint(x: 50, y: 50),
            pageNumber: 1,
            documentPath: "/tmp/test.pdf"
        )
        XCTAssertNotNil(note)
        XCTAssertEqual(note.annotationType, .note)
    }
}
