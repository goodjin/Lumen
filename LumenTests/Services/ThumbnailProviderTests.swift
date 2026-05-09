import XCTest
@testable import PDFVeCore
import PDFKit
import AppKit

@MainActor
final class ThumbnailProviderTests: XCTestCase {

    private var provider: ThumbnailProvider!

    override func setUp() {
        super.setUp()
        provider = ThumbnailProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - VAL-CMPT-012: Cache Lifecycle

    func test_thumbnail_returns_same_instance_on_subsequent_calls() async {
        // Given: a PDF with at least one page
        let pdf = createTestPDF()
        guard let page = pdf.page(at: 0) else {
            XCTFail("Could not get page 0 from test PDF")
            return
        }

        // When: thumbnail is requested for the same page twice
        let thumbnail1 = await provider.thumbnail(for: page, pageIndex: 0)
        let thumbnail2 = await provider.thumbnail(for: page, pageIndex: 0)

        // Then: same NSImage instance is returned (cached)
        XCTAssertIdentical(thumbnail1, thumbnail2, "Subsequent calls should return the same cached instance")
    }

    func test_thumbnail_returns_different_instances_for_different_pages() async {
        // Given: a multi-page PDF
        let pdf = createMultiPageTestPDF(pageCount: 3)
        guard let page0 = pdf.page(at: 0),
              let page1 = pdf.page(at: 1),
              let page2 = pdf.page(at: 2) else {
            XCTFail("Could not get pages from multi-page test PDF")
            return
        }

        // When: thumbnails are requested for different pages
        let thumbnail0 = await provider.thumbnail(for: page0, pageIndex: 0)
        let thumbnail1 = await provider.thumbnail(for: page1, pageIndex: 1)
        let thumbnail2 = await provider.thumbnail(for: page2, pageIndex: 2)

        // Then: each page returns a different thumbnail instance
        XCTAssertFalse(thumbnail0 === thumbnail1, "Different pages should have different thumbnails")
        XCTAssertFalse(thumbnail1 === thumbnail2, "Different pages should have different thumbnails")
        XCTAssertFalse(thumbnail0 === thumbnail2, "Different pages should have different thumbnails")
    }

    func test_clearCache_removes_all_entries() async {
        // Given: a multi-page PDF with thumbnails cached
        let pdf = createMultiPageTestPDF(pageCount: 3)
        guard let page0 = pdf.page(at: 0),
              let page1 = pdf.page(at: 1),
              let page2 = pdf.page(at: 2) else {
            XCTFail("Could not get pages from multi-page test PDF")
            return
        }

        // Pre-load thumbnails into cache and store references
        let thumbnail0Before = await provider.thumbnail(for: page0, pageIndex: 0)
        let thumbnail1Before = await provider.thumbnail(for: page1, pageIndex: 1)
        let thumbnail2Before = await provider.thumbnail(for: page2, pageIndex: 2)

        // When: clearCache is called
        await provider.clearCache()

        // Then: requesting thumbnails again returns NEW instances (not the cached ones)
        // This verifies clearCache actually emptied the cache
        let thumbnail0After = await provider.thumbnail(for: page0, pageIndex: 0)
        let thumbnail1After = await provider.thumbnail(for: page1, pageIndex: 1)
        let thumbnail2After = await provider.thumbnail(for: page2, pageIndex: 2)

        // Each "after" thumbnail should be a different instance than the "before" one
        XCTAssertFalse(thumbnail0Before === thumbnail0After,
            "After clearCache, thumbnail0 should be a new instance")
        XCTAssertFalse(thumbnail1Before === thumbnail1After,
            "After clearCache, thumbnail1 should be a new instance")
        XCTAssertFalse(thumbnail2Before === thumbnail2After,
            "After clearCache, thumbnail2 should be a new instance")
    }

    func test_clearCache_allows_fresh_thumbnail_generation() async {
        // Given: a PDF page with cached thumbnail
        let pdf = createTestPDF()
        guard let page = pdf.page(at: 0) else {
            XCTFail("Could not get page 0 from test PDF")
            return
        }

        // Pre-cache thumbnail
        let originalThumbnail = await provider.thumbnail(for: page, pageIndex: 0)

        // When: cache is cleared and thumbnail is requested again
        await provider.clearCache()
        let freshThumbnail = await provider.thumbnail(for: page, pageIndex: 0)

        // Then: fresh thumbnail is generated (different instance)
        XCTAssertFalse(originalThumbnail === freshThumbnail,
            "After clearCache, a fresh thumbnail should be generated")
    }

    func test_concurrent_thumbnail_access_is_safe() async {
        // Given: a multi-page PDF
        let pdf = createMultiPageTestPDF(pageCount: 10)
        guard let _ = pdf.page(at: 0),
              let _ = pdf.page(at: 1),
              let _ = pdf.page(at: 2),
              let _ = pdf.page(at: 3),
              let _ = pdf.page(at: 4),
              let _ = pdf.page(at: 5),
              let _ = pdf.page(at: 6),
              let _ = pdf.page(at: 7),
              let _ = pdf.page(at: 8),
              let _ = pdf.page(at: 9) else {
            XCTFail("Could not get pages from multi-page test PDF")
            return
        }

        // When: concurrent thumbnail requests are made for the same page
        // Using async let to run concurrent tasks
        async let thumb0a: NSImage = provider.thumbnail(for: pdf.page(at: 0)!, pageIndex: 0)
        async let thumb0b: NSImage = provider.thumbnail(for: pdf.page(at: 0)!, pageIndex: 0)
        async let thumb0c: NSImage = provider.thumbnail(for: pdf.page(at: 0)!, pageIndex: 0)
        async let thumb0d: NSImage = provider.thumbnail(for: pdf.page(at: 0)!, pageIndex: 0)
        async let thumb1a: NSImage = provider.thumbnail(for: pdf.page(at: 1)!, pageIndex: 1)
        async let thumb1b: NSImage = provider.thumbnail(for: pdf.page(at: 1)!, pageIndex: 1)

        // Then: all concurrent requests complete successfully and return valid images
        let results = await [thumb0a, thumb0b, thumb0c, thumb0d, thumb1a, thumb1b]

        // All results should be non-nil NSImage instances
        for (index, thumbnail) in results.enumerated() {
            XCTAssertNotNil(thumbnail, "Thumbnail \(index) should not be nil")
            XCTAssertTrue(thumbnail.size.width > 0, "Thumbnail \(index) should have valid width")
            XCTAssertTrue(thumbnail.size.height > 0, "Thumbnail \(index) should have valid height")
        }

        // Same-page concurrent requests should return identical instances (due to caching)
        XCTAssertIdentical(results[0], results[1], "Concurrent requests for same page should return same cached instance")
        XCTAssertIdentical(results[0], results[2], "Concurrent requests for same page should return same cached instance")
        XCTAssertIdentical(results[0], results[3], "Concurrent requests for same page should return same cached instance")
    }

    // MARK: - Helper Methods

    /// Creates a minimal single-page PDF with the word "Test" on it
    private func createTestPDF() -> PDFDocument {
        let pdfData = Data("%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n4 0 obj<</Length 44>>\nstream\nBT /F1 12 Tf 50 700 Td (Test) Tj ET\nendstream\nendobj\n5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\nxref\n0 6\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000267 00000 n \n0000000361 00000 n \ntrailer<</Size 6/Root 1 0 R>>\nstartxref\n456\n%%EOF\n".utf8)
        return PDFDocument(data: pdfData)!
    }

    /// Creates a multi-page PDF with the specified number of pages
    private func createMultiPageTestPDF(pageCount: Int) -> PDFDocument {
        var pdfContent = "%PDF-1.4\n"
        pdfContent += "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"

        var pageRefs = ""
        var pageObjs = ""
        var contentRefs = ""
        var contentObjs = ""
        var xrefEntries = ""

        for i in 0..<pageCount {
            let pageObjNum = 3 + i * 2
            let contentObjNum = 4 + i * 2
            pageRefs += "\(pageObjNum) 0 R "
            contentRefs += "\(contentObjNum) 0 R "

            pageObjs += "\(pageObjNum) 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents \(contentObjNum) 0 R/Resources<</Font<</F1 \(pageObjNum + 1) 0 R>>>>>>endobj\n"
            contentObjs += "\(contentObjNum) 0 obj<</Length 44>>\nstream\nBT /F1 12 Tf 50 700 Td (Page \(i + 1)) Tj ET\nendstream\nendobj\n"
            xrefEntries += "0000000000 65535 f \n"
            xrefEntries += "0000000009 00000 n \n"
        }

        pdfContent += "2 0 obj<</Type/Pages/Kids[\(pageRefs)]/Count \(pageCount)>>endobj\n"
        pdfContent += pageObjs
        pdfContent += contentObjs

        // Add font objects
        for i in 0..<pageCount {
            let fontObjNum = 3 + i * 2 + 1
            pdfContent += "\(fontObjNum) 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n"
        }

        pdfContent += "xref\n"
        pdfContent += "0 \(3 + pageCount * 2 + 1)\n"
        pdfContent += "0000000000 65535 f \n"
        pdfContent += "0000000009 00000 n \n"
        pdfContent += "0000000058 00000 n \n"
        pdfContent += "0000000115 00000 n \n"
        pdfContent += "0000000267 00000 n \n"
        pdfContent += "0000000361 00000 n \n"

        pdfContent += "trailer<</Size \(3 + pageCount * 2 + 1)/Root 1 0 R>>\n"
        pdfContent += "startxref\n"
        pdfContent += "456\n"
        pdfContent += "%%EOF\n"

        return PDFDocument(data: pdfContent.data(using: .ascii)!)!
    }
}
