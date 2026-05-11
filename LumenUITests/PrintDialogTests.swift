import XCTest
import AppKit

/// VAL-E2E-012: Print — Opens Dialog
/// Open PDF. Press Cmd+P. macOS print dialog appears.
@MainActor
final class PrintDialogTests: XCTestCase {

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

        testPDFURL = createTestPDF()
        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        app.launchArguments = ["--uitesting", "--open-pdf=\(testPDFURL.path)"]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testPDFURL)
    }

    // MARK: - VAL-E2E-012: Print Dialog

    func testPrintDialogOpens() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")

        // Wait for PDF to load
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")

        // Press Cmd+P to open print dialog
        app.typeKey("p", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)

        // macOS print dialog should appear as a sheet or separate window
        // Look for print-related UI elements
        let printDialog = app.dialogs.firstMatch
        let sheet = app.sheets.firstMatch

        // Check for print dialog by looking for Print button or cancel button
        let hasPrintDialog = printDialog.waitForExistence(timeout: 5) || sheet.waitForExistence(timeout: 5)

        if hasPrintDialog {
            // Dialog found - verify it contains print-related elements
            let cancelButton = app.buttons["取消"]
            XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Print dialog should have Cancel button")
        } else {
            // Alternative: check menu bar for print panel
            // On macOS, the print command opens a sheet or the print panel
            XCTFail("Print dialog did not appear after Cmd+P")
        }
    }

    // MARK: - Test Fixture

    private func createTestPDF() -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("PrintTest_\(UUID().uuidString).pdf")
        let text = "Test PDF for printing"
        let pdfContent = "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n4 0 obj<</Length 44>>\nstream\nBT /F1 12 Tf 50 700 Td (\(text)) Tj ET\nendstream\nendobj\n5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\nxref\n0 6\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\n0000000266 00000 n\n0000000360 00000 n\ntrailer<</Size 6/Root 1 0 R>>\nstartxref\n441\n%%EOF"
        try! pdfContent.write(to: pdfURL, atomically: true, encoding: .ascii)
        return pdfURL
    }
}
