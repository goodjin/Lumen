import XCTest
@testable import PDFVeCore
import PDFKit
import SwiftData

@MainActor
final class DocumentViewModelTests: XCTestCase {

    private var viewModel: DocumentViewModel!
    private var fileService: FileService!
    private var docRepo: DocumentRepository!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let schema = Schema([DocumentRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        docRepo = DocumentRepository(context: container.mainContext)
        fileService = FileService(docRepo: docRepo)
        viewModel = DocumentViewModel(fileService: fileService)
    }

    override func tearDown() {
        viewModel = nil
        fileService = nil
        docRepo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - VAL-CMPT-013: Recent Files API

    func test_removeRecent_deletes_specific_record() {
        // Given: add two recent documents
        try? docRepo.recordOpen(filePath: "/tmp/doc1.pdf", fileName: "doc1.pdf", pageCount: 10)
        try? docRepo.recordOpen(filePath: "/tmp/doc2.pdf", fileName: "doc2.pdf", pageCount: 20)
        viewModel.recentDocuments = fileService.recentDocuments()
        XCTAssertEqual(viewModel.recentDocuments.count, 2)

        // When: remove one specific record
        viewModel.removeRecent(viewModel.recentDocuments.first { $0.filePath == "/tmp/doc1.pdf" }!)

        // Then: only the other record remains
        XCTAssertEqual(viewModel.recentDocuments.count, 1)
        XCTAssertEqual(viewModel.recentDocuments.first?.filePath, "/tmp/doc2.pdf")
    }

    func test_clearRecentDocuments_empties_list() {
        // Given: add multiple recent documents
        for i in 0..<5 {
            try? docRepo.recordOpen(filePath: "/tmp/doc\(i).pdf", fileName: "doc\(i).pdf", pageCount: 10)
        }
        viewModel.recentDocuments = fileService.recentDocuments()
        XCTAssertFalse(viewModel.recentDocuments.isEmpty)

        // When: clear all recent documents
        viewModel.clearRecentDocuments()

        // Then: list is empty
        XCTAssertTrue(viewModel.recentDocuments.isEmpty)
    }

    // MARK: - FileService Reading State (indirect test via repo)

    func test_fileService_readingState_returns_persisted_page_and_zoom() throws {
        // Given: a document record with reading state
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        try docRepo.recordOpen(filePath: url.path, fileName: "test.pdf", pageCount: 10)
        try docRepo.updateReadingState(filePath: url.path, page: 5, zoom: 2.5)

        // When: reading state is retrieved
        let readingState = try docRepo.readingState(for: url.path)

        // Then: page and zoom are correct
        XCTAssertEqual(readingState?.page, 5)
        XCTAssertEqual(readingState?.zoom, 2.5)
    }

    func test_fileService_readingState_returns_nil_for_unknown_path() throws {
        // When: reading state is retrieved for unknown path
        let readingState = try docRepo.readingState(for: "/tmp/unknown.pdf")

        // Then: returns nil
        XCTAssertNil(readingState)
    }
}
