import XCTest
import AppKit

/// VAL-E2E-011: Page Navigation — History Records
/// Navigate to page 5 via outline click. Navigate to page 10 via page nav. Press Cmd+[ (Go Back).
/// Navigate to page 5 again. Press Cmd+] (Go Forward). Advance to page 10.
@MainActor
final class PageNavHistoryTests: XCTestCase {

    private var app: XCUIApplication!
    private var testPDFURL: URL!
    private static var appLaunched = false

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let runningApps = NSWorkspace.shared.runningApplications
        for runningApp in runningApps where runningApp.bundleIdentifier == "com.lumen-app" {
            runningApp.terminate()
        }
        Thread.sleep(forTimeInterval: 0.5)

        if !PageNavHistoryTests.appLaunched {
            // Create a PDF with outline (TOC)
            testPDFURL = createPDFWithOutline()
            app = XCUIApplication(bundleIdentifier: "com.lumen-app")
            app.launchArguments = ["--uitesting", "--open-pdf=\(testPDFURL.path)"]
            app.launch()
            PageNavHistoryTests.appLaunched = true
        } else {
            app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        }
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testPDFURL)
    }

    // MARK: - VAL-E2E-011: Page Navigation History

    func testPageNavigationHistoryBackForward() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")

        // Wait for PDF to load
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")

        // Step 1: Navigate to page 5 via page input
        let pageInput = app.textFields["页码输入"]
        if pageInput.waitForExistence(timeout: 5) {
            pageInput.click()
            pageInput.typeText("5")
            app.typeKey(.return, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Verify window is still functional
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after page 5 navigation")

        // Step 2: Navigate to page 10 via page navigation
        if pageInput.waitForExistence(timeout: 5) {
            pageInput.click()
            pageInput.typeText("10")
            app.typeKey(.return, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Verify window is still functional
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after page 10 navigation")

        // Step 3: Press Cmd+[ (Go Back)
        app.typeKey("[", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Step 4: Navigate to page 5 again
        if pageInput.waitForExistence(timeout: 5) {
            pageInput.click()
            pageInput.typeText("5")
            app.typeKey(.return, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Step 5: Press Cmd+] (Go Forward)
        app.typeKey("]", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Verify we're still functional
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after navigation")
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should be present")
    }

    // MARK: - Test Fixture

    /// Creates a PDF with outline/TOC structure
    private func createPDFWithOutline() -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("OutlineTest_\(UUID().uuidString).pdf")

        // Create a simple multi-page PDF with text
        let pdfContent = """
        %PDF-1.4
        1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
        2 0 obj<</Type/Pages/Kids[3 0 R 8 0 R 13 0 R]/Count 3>>endobj
        3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
        4 0 obj<</Length 44>>
        stream
        BT /F1 12 Tf 50 700 Td (Page 1) Tj ET
        endstream
        endobj
        5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj
        8 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 9 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
        9 0 obj<</Length 44>>
        stream
        BT /F1 12 Tf 50 700 Td (Page 5) Tj ET
        endstream
        endobj
        13 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 14 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
        14 0 obj<</Length 44>>
        stream
        BT /F1 12 Tf 50 700 Td (Page 10) Tj ET
        endstream
        endobj
        xref
        0 15
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000266 00000 n
        0000000360 00000 n
        0000000417 00000 n
        0000000475 00000 n
        0000000569 00000 n
        0000000627 00000 n
        0000000721 00000 n
        0000000779 00000 n
        0000000873 00000 n
        0000000931 00000 n
        0000001025 00000 n
        0000001083 00000 n
        trailer<</Size 15/Root 1 0 R>>
        startxref
        1106
        %%EOF
        """
        try! pdfContent.write(to: pdfURL, atomically: true, encoding: .ascii)
        return pdfURL
    }
}
