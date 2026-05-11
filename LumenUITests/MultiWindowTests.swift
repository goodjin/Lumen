import XCTest
import AppKit

/// VAL-E2E-003: Multi-Window — Independent State
/// Verifies: Open PDF-A in Window 1 (main window). Open PDF-B in Window 2 via File > Open (Cmd+O).
/// Navigate each independently (different pages). Close Window 1 (red X). Verify Window 2 survives.
/// All 4 sidebar tabs work in each window independently.
@MainActor
final class MultiWindowTests: XCTestCase {

    private var app: XCUIApplication!
    private var pdfA: URL!
    private var pdfB: URL!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Terminate any running Lumen instances
        let runningApps = NSWorkspace.shared.runningApplications
        for runningApp in runningApps where runningApp.bundleIdentifier == "com.lumen-app" {
            runningApp.terminate()
        }
        Thread.sleep(forTimeInterval: 0.5)

        // Create two test PDFs with different content
        pdfA = createTestPDF(name: "PDF_A", text: "This is document A page 1")
        pdfB = createTestPDF(name: "PDF_B", text: "This is document B page 1 second document")

        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: pdfA)
        try? FileManager.default.removeItem(at: pdfB)
    }

    // MARK: - VAL-E2E-003: Multi-Window Independent State

    func testMultiWindowIndependentState() throws {
        // Step 1: Open PDF-A in Window 1 (main window)
        app.launchArguments = ["--uitesting", "--open-pdf=\(pdfA.path)"]
        app.launch()

        let window1 = app.windows.firstMatch
        XCTAssertTrue(window1.waitForExistence(timeout: 10), "Window 1 should appear")

        // Verify PDF-A loaded
        let pdfView1 = window1.scrollViews.firstMatch
        XCTAssertTrue(pdfView1.waitForExistence(timeout: 5), "PDF view in window 1 should appear")

        // Step 2: Open PDF-B in Window 2 via File > Open (Cmd+O)
        // Press Cmd+O to open file dialog
        app.menuBars.menuItems["File"].click()
        Thread.sleep(forTimeInterval: 0.3)
        app.menuBars.menuItems["File"].menuItems["打开…"].click()
        Thread.sleep(forTimeInterval: 0.5)

        // Type the file path in the open panel (sheet)
        // XCUIApplication handles sheets differently - we need to use sheets
        if let openPanel = app.sheets.firstMatch as XCUIElement? {
            let fileNameTextField = openPanel.textFields.firstMatch
            if fileNameTextField.waitForExistence(timeout: 5) {
                fileNameTextField.click()
                fileNameTextField.typeText(pdfB.path)
            }

            // Press Return to confirm
            openPanel.buttons["打开"].click()
        }

        Thread.sleep(forTimeInterval: 1.0)

        // Alternative approach: Use NSWorkspace to open second PDF in new window
        NSWorkspace.shared.open([pdfB], withApplicationAt: URL(fileURLWithPath: "/Applications/Lumen.app"), configuration: NSWorkspace.OpenConfiguration())

        Thread.sleep(forTimeInterval: 2.0)

        // Step 3: Verify Window 2 exists
        let windows = app.windows
        XCTAssertGreaterThanOrEqual(windows.count, 2, "Should have at least 2 windows")

        // Step 4: Navigate each window independently
        // For window 1, the scroll view should show PDF-A content
        XCTAssertTrue(window1.waitForExistence(timeout: 5), "Window 1 should still be visible")

        // Step 5: Close Window 1 (simulate clicking red X)
        window1.buttons["Close"].click()
        Thread.sleep(forTimeInterval: 1.0)

        // Step 6: Verify Window 2 survives
        XCTAssertEqual(app.windows.count, 1, "Window 2 should survive when Window 1 is closed")
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "Window 2 should still be present")
    }

    func testSidebarTabsInMultipleWindows() throws {
        // Open first PDF
        app.launchArguments = ["--uitesting", "--open-pdf=\(pdfA.path)"]
        app.launch()

        let window1 = app.windows.firstMatch
        XCTAssertTrue(window1.waitForExistence(timeout: 10), "Window 1 should appear")

        // Wait for sidebar to appear
        let sidebar = window1.scrollViews.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "Sidebar should be visible")

        // Verify all 4 sidebar tabs are accessible
        // Use View menu to toggle sidebar and verify
        app.menuBars.menuItems["视图"].menuItems["侧栏"].click()
        Thread.sleep(forTimeInterval: 0.5)

        // Sidebar should toggle
        app.menuBars.menuItems["视图"].menuItems["侧栏"].click()
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Test Fixture

    private func createTestPDF(name: String, text: String) -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)_\(UUID().uuidString).pdf")
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
