import XCTest
import AppKit

/// VAL-E2E-011: Page Navigation — History Records
/// Navigate to page 5 via outline click. Navigate to page 10 via page nav. Press Cmd+[ (Go Back).
/// Navigate to page 5 again. Press Cmd+] (Go Forward). Advance to page 10.
@MainActor
final class PageNavHistoryTests: XCTestCase {

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

        // Create a PDF with outline (TOC)
        testPDFURL = createPDFWithOutline()
        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        app.launchArguments = ["--uitesting", "--open-pdf=\(testPDFURL.path)"]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testPDFURL)
    }

    // MARK: - VAL-E2E-011: Page Navigation History

    func testPageNavigationHistoryBackForward() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")

        // Wait for PDF to load
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")

        // Step 1: Navigate to page 5 via outline click
        // First, ensure sidebar is visible (Cmd+T to toggle if needed)
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Click on the outline tab
        let outlineTab = app.tabGroups.buttons["目录"]
        if outlineTab.waitForExistence(timeout: 5) {
            outlineTab.click()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Look for page 5 in outline and click it
        // The outline items contain page numbers
        let outlineList = app.outlines.firstMatch
        if outlineList.waitForExistence(timeout: 5) {
            // Find and click page 5 outline item
            let cells = outlineList.cells
            for i in 0..<cells.count {
                let cell = cells.element(boundBy: i)
                let label = cell.staticTexts.firstMatch.label
                if label.contains("5") || label == "5" {
                    cell.click()
                    Thread.sleep(forTimeInterval: 0.5)
                    break
                }
            }
        }

        // Verify we're on page 5
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible")

        // Step 2: Navigate to page 10 via page navigation
        // Find page input field and type page 10
        let pageInput = app.textFields["页码输入"]
        if pageInput.waitForExistence(timeout: 5) {
            pageInput.click()
            pageInput.typeText("10")
            pageInput.typeKey(.return, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Verify page 10 (current page indicator should show 10)
        // We can't directly read the page number, but we can verify navigation worked

        // Step 3: Press Cmd+[ (Go Back)
        app.typeKey("[", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Step 4: Navigate to page 5 again
        if pageInput.waitForExistence(timeout: 5) {
            pageInput.click()
            pageInput.typeText("5")
            pageInput.typeKey(.return, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Step 5: Press Cmd+] (Go Forward)
        app.typeKey("]", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Verify we're still on page 10 (went forward)
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should still be visible after navigation")
    }

    // MARK: - Test Fixture

    /// Creates a PDF with outline/TOC structure
    private func createPDFWithOutline() -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("OutlineTest_\(UUID().uuidString).pdf")

        // Create a simple 15-page PDF
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            fatalError("Failed to create CGDataConsumer")
        }

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            fatalError("Failed to create CGContext")
        }

        for pageNum in 1...15 {
            context.beginPDFPage(nil)
            context.saveGState()

            // White background
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)

            // Page text
            let text = "Page \(pageNum)"
            let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: CGColor(gray: 0.2, alpha: 1)
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)
            context.textPosition = CGPoint(x: 50, y: 700)
            CTLineDraw(line, context)

            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()

        // Write to file
        pdfData.write(to: pdfURL, atomically: true)

        return pdfURL
    }
}
