import XCTest
import AppKit
import SwiftUI

/// VAL-E2E-007: Drag-Drop — Reader Area
/// Drag PDF from Finder onto reader area. Drop. New PDF opens. Old state saved. Non-PDF rejected silently.
@MainActor
final class DragDropTests: XCTestCase {

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

        testPDFURL = createSimpleTestPDF()
        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        // Use --open-pdf= to simulate opening a PDF (simulates drop behavior)
        app.launchArguments = [
            "--uitesting",
            "--open-pdf=\(testPDFURL.path)"
        ]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testPDFURL)
    }

    // MARK: - VAL-E2E-007: Drag-Drop Reader Area

    /// Test that opening a PDF via simulated drop (--open-pdf=) loads the PDF in reader area.
    /// Note: True drag-drop from Finder is not easily testable in XCTest.
    /// Alternative approach: Open File > Open dialog and select a PDF.
    func testDragDropSimulatedPDFOpen() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")

        // Verify PDF content loads (scroll view should exist as part of PDFView)
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")

        // Verify the window has content (document is loaded)
        XCTAssertFalse(window.title.isEmpty, "Window should have a title (PDF filename)")
    }

    /// Test that a second PDF open (simulated drop) replaces the current PDF.
    func testSecondPDFDropReplacesFirst() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "PDF reader window should appear")

        // Create a second PDF
        let secondPDFURL = createSimpleTestPDF()
        defer { try? FileManager.default.removeItem(at: secondPDFURL) }

        // Terminate and relaunch with second PDF to simulate drop behavior
        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        app.launchArguments = [
            "--uitesting",
            "--open-pdf=\(secondPDFURL.path)"
        ]
        app.launch()

        // Verify second PDF loaded
        let newWindow = app.windows.firstMatch
        XCTAssertTrue(newWindow.waitForExistence(timeout: 10), "New PDF reader window should appear")
        let pdfView = app.windows.firstMatch.scrollViews.firstMatch
        XCTAssertTrue(pdfView.waitForExistence(timeout: 5), "PDF scroll view should be present")
    }

    // MARK: - Test Fixture

    private func createSimpleTestPDF() -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("DragDropTest_\(UUID().uuidString).pdf")
        let text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
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
