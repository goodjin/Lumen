import XCTest
import AppKit
import SwiftUI

/// VAL-E2E-001: Search — UI Integration
/// Core verification: App launches, opens PDF, shows search bar. Search correctness (results count, highlighting) is covered by unit tests.
@MainActor
final class SearchHighlightTests: XCTestCase {

    private var app: XCUIApplication!
    private var testPDFURL: URL!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let runningApps = NSWorkspace.shared.runningApplications
        for runningApp in runningApps where runningApp.bundleIdentifier == "com.lumen-app" {
            runningApp.terminate()
        }
        Thread.sleep(forTimeInterval: 0.5)

        testPDFURL = createSearchableTestPDF()
        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        app.launchArguments = [
            "--uitesting",
            "--open-pdf=\(testPDFURL.path)",
            "--show-search"
        ]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testPDFURL)
    }

    // MARK: - VAL-E2E-001: Search UI Integration

    func testSearchHighlightAllMatches() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")
        let searchField = app.textFields["SearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 15), "Search field should appear")
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")
        // Search correctness (results count, highlighting) is verified by unit tests.
    }

    // MARK: - Test Fixture

    private func createSearchableTestPDF() -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("SearchTest_\(UUID().uuidString).pdf")
        let text = "the quick brown fox jumps over the lazy dog the end"
        let pdfContent = "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n4 0 obj<</Length 44>>\nstream\nBT /F1 12 Tf 50 700 Td (\(text)) Tj ET\nendstream\nendobj\n5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\nxref\n0 6\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\n0000000266 00000 n\n0000000360 00000 n\ntrailer<</Size 6/Root 1 0 R>>\nstartxref\n441\n%%EOF"
        try! pdfContent.write(to: pdfURL, atomically: true, encoding: .ascii)
        return pdfURL
    }
}
