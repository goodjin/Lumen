import XCTest
@testable import PDFVeCore
import SwiftData

@MainActor
final class BookmarkServiceTests: XCTestCase {

    private var service: BookmarkService!
    private var repo: BookmarkRepository!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let schema = Schema([BookmarkRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        repo = BookmarkRepository(context: container.mainContext)
        service = BookmarkService(repository: repo)
    }

    override func tearDown() {
        service = nil
        repo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - API-063 toggleBookmark

    @MainActor
    func test_toggleBookmark_creates_bookmark_when_none_exists() {
        service.toggleBookmark(at: 5, in: "/tmp/test.pdf")
        let bookmarks = service.bookmarks(for: "/tmp/test.pdf")
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks[0].pageNumber, 5)
    }

    @MainActor
    func test_toggleBookmark_removes_bookmark_when_exists() {
        service.toggleBookmark(at: 5, in: "/tmp/test.pdf")
        XCTAssertEqual(service.bookmarks(for: "/tmp/test.pdf").count, 1)

        service.toggleBookmark(at: 5, in: "/tmp/test.pdf")
        XCTAssertTrue(service.bookmarks(for: "/tmp/test.pdf").isEmpty)
    }

    // MARK: - API-064 renameBookmark

    @MainActor
    func test_renameBookmark_ignores_empty_string() {
        service.toggleBookmark(at: 5, in: "/tmp/test.pdf")
        let bookmark = service.bookmarks(for: "/tmp/test.pdf")[0]
        let originalName = bookmark.name

        service.renameBookmark(id: bookmark.id, name: "", in: "/tmp/test.pdf")
        XCTAssertEqual(bookmark.name, originalName)
    }

    @MainActor
    func test_renameBookmark_updates_name() {
        service.toggleBookmark(at: 5, in: "/tmp/test.pdf")
        let bookmark = service.bookmarks(for: "/tmp/test.pdf")[0]
        let id = bookmark.id

        service.renameBookmark(id: id, name: "My Bookmark", in: "/tmp/test.pdf")
        XCTAssertEqual(bookmark.name, "My Bookmark")
    }

    // MARK: - API-066 deleteBookmark

    @MainActor
    func test_deleteBookmark_removes_bookmark() {
        service.toggleBookmark(at: 5, in: "/tmp/test.pdf")
        let bookmark = service.bookmarks(for: "/tmp/test.pdf")[0]
        let id = bookmark.id

        service.deleteBookmark(id: id)
        XCTAssertTrue(service.bookmarks(for: "/tmp/test.pdf").isEmpty)
    }

    // MARK: - isBookmarked

    @MainActor
    func test_isBookmarked_returns_true_when_bookmarked() {
        XCTAssertFalse(service.isBookmarked(pageNumber: 5, documentPath: "/tmp/test.pdf"))
        service.toggleBookmark(at: 5, in: "/tmp/test.pdf")
        XCTAssertTrue(service.isBookmarked(pageNumber: 5, documentPath: "/tmp/test.pdf"))
    }
}
