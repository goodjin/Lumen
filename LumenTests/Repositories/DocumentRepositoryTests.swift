import XCTest
@testable import PDFVeCore
import SwiftData

@MainActor
final class DocumentRepositoryTests: XCTestCase {

    private var repo: DocumentRepository!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let schema = Schema([DocumentRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        repo = DocumentRepository(context: container.mainContext)
    }

    override func tearDown() {
        repo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - recordOpen creates new entry

    @MainActor
    func test_recordOpen_inserts_new_record() throws {
        try repo.recordOpen(filePath: "/tmp/doc.pdf", fileName: "doc.pdf", pageCount: 10)
        let recent = try repo.fetchRecent()
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].fileName, "doc.pdf")
    }

    // MARK: - recordOpen updates existing entry

    @MainActor
    func test_recordOpen_updates_existing_record() throws {
        try repo.recordOpen(filePath: "/tmp/doc.pdf", fileName: "doc.pdf", pageCount: 10)
        try repo.recordOpen(filePath: "/tmp/doc.pdf", fileName: "doc.pdf", pageCount: 20)
        let recent = try repo.fetchRecent()
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].pageCount, 20)
    }

    // MARK: - Rule-004: max 20 recent files

    @MainActor
    func test_recordOpen_prunes_above_20_records() throws {
        for i in 0..<25 {
            try repo.recordOpen(filePath: "/tmp/doc\(i).pdf", fileName: "doc\(i).pdf", pageCount: 10)
        }
        let recent = try repo.fetchRecent()
        XCTAssertEqual(recent.count, 20)
    }

    // MARK: - remove

    @MainActor
    func test_remove_deletes_record() throws {
        try repo.recordOpen(filePath: "/tmp/doc.pdf", fileName: "doc.pdf", pageCount: 10)
        try repo.remove(filePath: "/tmp/doc.pdf")
        let recent = try repo.fetchRecent()
        XCTAssertTrue(recent.isEmpty)
    }

    // MARK: - updateReadingState

    @MainActor
    func test_updateReadingState_saves_page_and_zoom() throws {
        try repo.recordOpen(filePath: "/tmp/doc.pdf", fileName: "doc.pdf", pageCount: 10)
        try repo.updateReadingState(filePath: "/tmp/doc.pdf", page: 5, zoom: 2.0)
        let state = try repo.readingState(for: "/tmp/doc.pdf")
        XCTAssertEqual(state?.page, 5)
        XCTAssertEqual(state?.zoom, 2.0)
    }

    // MARK: - readingState returns nil for unknown path

    @MainActor
    func test_readingState_returns_nil_for_unknown_path() throws {
        let state = try repo.readingState(for: "/tmp/unknown.pdf")
        XCTAssertNil(state)
    }
}
