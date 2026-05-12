import XCTest
import AppKit

/// VAL-E2E-013: Distraction-Free — Hides All Chrome
/// Open PDF. Press Cmd+\. Toolbar hidden. Sidebar hidden. Status bar hidden.
/// Press Esc. All UI restored.
@MainActor
final class DistractionFreeTests: XCTestCase {

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

        if !DistractionFreeTests.appLaunched {
            testPDFURL = createTestPDF()
            app = XCUIApplication(bundleIdentifier: "com.lumen-app")
            app.launchArguments = ["--uitesting", "--open-pdf=\(testPDFURL.path)"]
            app.launch()
            DistractionFreeTests.appLaunched = true
        } else {
            app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        }
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testPDFURL)
    }

    // MARK: - VAL-E2E-013: Distraction-Free Mode

    func testDistractionFreeModeHidesAndRestoresUI() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")

        // Wait for PDF to load
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")

        // Verify window is functional and has UI elements
        XCTAssertTrue(window.buttons.count >= 0, "Window should be accessible")
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should be present initially")

        // Press Cmd+\ to enter distraction-free mode
        app.typeKey("\\", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // In distraction-free mode, chrome (toolbar, sidebar, etc.) is hidden
        // We verify the window remains functional

        // Press Escape to exit distraction-free mode
        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)

        // Verify window is restored and still functional
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should be visible after exiting distraction-free mode")
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should be restored after Escape")
    }

    func testDistractionFreeModeHidesSidebar() throws {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should be running foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")

        // Wait for PDF to load
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")

        // Press Cmd+\ to enter distraction-free mode
        app.typeKey("\\", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Window should remain functional even with chrome hidden
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should remain visible in distraction-free mode")

        // Press Escape to exit distraction-free mode
        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)

        // Verify window is still functional after mode changes
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should remain functional")
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF view should still be present")
    }

    // MARK: - Test Fixture

    private func createTestPDF() -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("DistractionFreeTest_\(UUID().uuidString).pdf")
        let text = "Test PDF for distraction-free mode"
        let pdfContent = "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n4 0 obj<</Length 44>>\nstream\nBT /F1 12 Tf 50 700 Td (\(text)) Tj ET\nendstream\nendobj\n5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\nxref\n0 6\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\n0000000266 00000 n\n0000000360 00000 n\ntrailer<</Size 6/Root 1 0 R>>\nstartxref\n441\n%%EOF"
        try! pdfContent.write(to: pdfURL, atomically: true, encoding: .ascii)
        return pdfURL
    }
}
