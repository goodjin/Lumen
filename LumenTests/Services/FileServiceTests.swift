import XCTest
@testable import PDFVeCore
import PDFKit
import SwiftData

@MainActor
final class FileServiceTests: XCTestCase {

    private var service: FileService!
    private var repo: DocumentRepository!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let schema = Schema([DocumentRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        repo = DocumentRepository(context: container.mainContext)
        service = FileService(docRepo: repo)
    }

    override func tearDown() {
        service = nil
        repo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - openDocument 校验

    func test_openDocument_rejects_non_pdf_extension() async {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        do {
            _ = try await service.openDocument(at: url)
            XCTFail("Should throw FileError.invalidPDF")
        } catch let error as FileError {
            XCTAssertEqual(error, .invalidPDF)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_openDocument_rejects_nonexistent_file() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent.pdf")
        do {
            _ = try await service.openDocument(at: url)
            XCTFail("Should throw FileError.notFound")
        } catch let error as FileError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - closeDocument 静默失败

    func test_closeDocument_does_not_throw() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        // 不应抛异常
        service.closeDocument(at: url, currentPage: 5, zoomLevel: 1.5)
    }

    // MARK: - recentDocuments

    func test_recentDocuments_returns_repo_results() {
        // 初始为空
        XCTAssertTrue(service.recentDocuments().isEmpty)
    }
}
