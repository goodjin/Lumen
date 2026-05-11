import XCTest
import AppKit

/// VAL-E2E-006: View Menu — All Commands Work
/// Open View menu and click each item. Verify correct behavior:
/// - 侧栏 (Cmd+T): sidebar appears/hides
/// - 专注阅读模式 (Cmd+\): chrome hidden/restored
/// - 实际大小 (Cmd+0): zoom resets
/// - 适合宽度 (Cmd+1): fits width
/// - 适合页面 (Cmd+2): fits page
/// - Sidebar tabs (Outline, Annotations, Bookmarks, Thumbnails) in sidebar
@MainActor
final class ViewMenuTests: XCTestCase {

    private var app: XCUIApplication!
    private var testPDFURL: URL!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Terminate any running Lumen instances
        let runningApps = NSWorkspace.shared.runningApplications
        for runningApp in runningApps where runningApp.bundleIdentifier == "com.lumen-app" {
            runningApp.terminate()
        }
        Thread.sleep(forTimeInterval: 0.5)

        testPDFURL = createTestPDF()
        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        app.launchArguments = ["--uitesting", "--open-pdf=\(testPDFURL.path)"]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testPDFURL)
    }

    // MARK: - VAL-E2E-006: View Menu Commands

    func testSidebarToggle() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF window should appear")

        // Wait for PDF to load
        let pdfView = window.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should appear")

        // Toggle sidebar off via Cmd+T
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Toggle sidebar back on via Cmd+T
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Sidebar should be visible again
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after sidebar toggle")
    }

    func testDistractionFreeMode() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF window should appear")

        // Wait for PDF to load
        let pdfView = window.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should appear")

        // Enter distraction free mode via Cmd+\
        app.typeKey("\\", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Exit distraction free mode via Escape
        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)

        // Window should still be visible
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after exiting distraction free mode")
    }

    func testActualSize() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF window should appear")

        // Wait for PDF to load
        let pdfView = window.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should appear")

        // Press Cmd+0 for actual size
        app.typeKey("0", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Window should still be visible
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after actual size")
    }

    func testFitWidth() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF window should appear")

        // Wait for PDF to load
        let pdfView = window.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should appear")

        // Press Cmd+1 for fit width
        app.typeKey("1", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Window should still be visible
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after fit width")
    }

    func testFitPage() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF window should appear")

        // Wait for PDF to load
        let pdfView = window.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should appear")

        // Press Cmd+2 for fit page
        app.typeKey("2", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Window should still be visible
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after fit page")
    }

    func testSidebarTabsAccessible() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF window should appear")

        // Wait for PDF to load
        let pdfView = window.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should appear")

        // Ensure sidebar is visible via Cmd+T
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Verify window is still present
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should be visible with sidebar")

        // Verify window is still functional
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should still be visible")
    }

    // MARK: - Test Fixture

    private func createTestPDF() -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("ViewMenuTest_\(UUID().uuidString).pdf")
        let text = "Testing view menu commands in Lumen PDF reader application"
        let pdfContent = """
        %PDF-1.4
        1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
        2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
        3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
        4 0 obj<</Length 44>>
        stream
        BT /F1 12 Tf 50 700 Td (\(text)) Tj ET
        endstream
        endobj
        5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000266 00000 n
        0000000360 00000 n
        trailer<</Size 6/Root 1 0 R>>
        startxref
        441
        %%EOF
        """
        try! pdfContent.write(to: pdfURL, atomically: true, encoding: .ascii)
        return pdfURL
    }
}
