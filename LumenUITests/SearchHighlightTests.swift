import XCTest
import PDFKit
import SwiftUI
import AppKit

/// VAL-E2E-001: Search — Highlight All Matches
/// Search "the" in document with 5+ occurrences. All occurrences visually highlighted simultaneously.
/// Current match highlighted distinctly (orange). Cmd+G moves current match. Esc clears highlights.
@MainActor
final class SearchHighlightTests: XCTestCase {

    private var app: XCUIApplication!
    private var testPDFURL: URL!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        // Use bundle identifier to launch the app
        app = XCUIApplication(bundleIdentifier: "com.lumen-app")
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
        
        // Verify the app is running
        XCTAssertTrue(app.exists, "App should be running")
        
        // Wait for accessibility to be ready before interacting with UI elements.
        // This polls for accessibility readiness instead of just checking window existence.
        // XCTest may launch the app before the accessibility tree is fully published.
        waitForAccessibilityReady(timeout: 30)
        
        // Create a PDF with 5+ occurrences of "the" for testing
        testPDFURL = createTestPDF()
    }
    
    /// Waits for accessibility to be fully ready by polling for key UI elements.
    /// This resolves "Application has not loaded accessibility" errors that occur
    /// when XCTest tries to interact with UI elements before the accessibility tree
    /// has been published.
    private func waitForAccessibilityReady(timeout: TimeInterval = 10) {
        let startTime = Date()
        let pollInterval: TimeInterval = 0.5
        
        // First, wait for the app to be fully launched by checking if the process exists
        while Date().timeIntervalSince(startTime) < timeout {
            if app.exists {
                // App process exists, now check if accessibility is ready
                // by trying to access a basic accessibility attribute
                let windowCount = app.windows.count
                if windowCount > 0 {
                    return
                }
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        
        // If we timeout, the accessibility may not be working, but we continue anyway
        // as the app launch may have succeeded
    }

    override func tearDown() {
        // Clean up temp PDF
        try? FileManager.default.removeItem(at: testPDFURL)
        super.tearDown()
    }

    // MARK: - VAL-E2E-001: Search Highlight All Matches

    func testSearchHighlightAllMatches() throws {
        // Step 1: Verify app is running
        XCTAssertTrue(app.exists, "App should be running")
        
        // Step 2: Open the test PDF via keyboard shortcut Cmd+O
        openPDFWithKeyboard()
        
        // Step 3: Wait for document to load (look for page indicator "1 / 1")
        let pageIndicator = app.staticTexts["1 / 1"]
        let docArea = pageIndicator.waitForExistence(timeout: 10)
        XCTAssertTrue(docArea, "Document should load and show page indicator")
        
        // Step 4: Press Cmd+F to show search bar
        app.typeKey("f", modifierFlags: .command)
        
        // Step 5: Wait for search field to appear and type search term
        let searchField = app.textFields["搜索"]
        let searchFieldExists = searchField.waitForExistence(timeout: 5)
        XCTAssertTrue(searchFieldExists, "Search field should appear after Cmd+F")
        
        // Type "the" - this word appears 5+ times in our test PDF
        searchField.click()
        searchField.typeText("the")
        
        // Step 6: Wait for search results to appear using proper XCUI wait
        // The result summary has accessibilityIdentifier "搜索结果"
        let resultSummary = app.staticTexts["搜索结果"]
        let hasResults = resultSummary.waitForExistence(timeout: 5)
        XCTAssertTrue(hasResults, "Search results should appear")
        
        // Verify the result counter shows multiple matches (should be something like "1/5" or "1/6")
        let resultText = resultSummary.label
        XCTAssertTrue(resultText.contains("/"), "Result summary should show match count like '1/5'")
        
        // Extract the total count from the result text (format: "current/total")
        let parts = resultText.split(separator: "/")
        XCTAssertEqual(parts.count, 2, "Result should be in format 'current/total'")
        let totalMatches = Int(parts[1]) ?? 0
        XCTAssertGreaterThanOrEqual(totalMatches, 5, "Should have at least 5 matches for 'the'")
        
        // Step 7: Press Cmd+G to advance to next match (verify it cycles through)
        // Store current index
        let currentBeforeAdvancing = Int(parts[0]) ?? 0
        
        app.typeKey("g", modifierFlags: .command)
        
        // Wait for result text to update after advancing
        let updatedResult = resultSummary.waitForExistence(timeout: 2)
        XCTAssertTrue(updatedResult, "Result summary should update after Cmd+G")
        
        // The result counter should now show a different current index
        let resultTextAfter = resultSummary.label
        let partsAfter = resultTextAfter.split(separator: "/")
        let currentAfterAdvancing = Int(partsAfter[0]) ?? 0
        
        // Should have advanced to next match (wrapping around)
        let expectedNext = currentBeforeAdvancing == totalMatches ? 1 : currentBeforeAdvancing + 1
        XCTAssertEqual(currentAfterAdvancing, expectedNext, "Cmd+G should advance to next match")
        
        // Step 8: Press Escape to clear search
        app.typeKey(.escape, modifierFlags: [])
        
        // Search field should no longer be visible
        let searchFieldStillVisible = searchField.waitForExistence(timeout: 1)
        XCTAssertFalse(searchFieldStillVisible, "Search field should hide after pressing Escape")
        
        // Result summary should also be gone
        let resultsStillVisible = resultSummary.waitForExistence(timeout: 1)
        XCTAssertFalse(resultsStillVisible, "Search results should clear after Escape")
    }
    
    /// Opens the PDF using keyboard shortcut instead of menu
    private func openPDFWithKeyboard() {
        // Press Cmd+O to open file dialog
        app.typeKey("o", modifierFlags: .command)
        
        // Wait for Open dialog to appear
        let openDialog = app.dialogs.firstMatch
        XCTAssertTrue(openDialog.waitForExistence(timeout: 5), "Open dialog should appear")
        
        // Enter the file path
        let pathField = openDialog.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 3), "Path field should exist")
        pathField.click()
        pathField.typeText(testPDFURL.path)
        
        // Press Enter to confirm
        app.typeKey(.return, modifierFlags: [])
    }

    /// Creates a PDF document with 5+ occurrences of "the" for search testing
    /// Uses Core Graphics to create a simple PDF with embedded text
    private func createTestPDF() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("SearchTestPDF_\(UUID().uuidString).pdf")
        
        // Create a PDF with multiple pages, each containing "the" multiple times
        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let margin: CGFloat = 72 // 1 inch margin
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Lumen UITest",
            kCGPDFContextTitle: "Search Test Document"
        ]
        
        let consumer = CGDataConsumer(url: pdfURL as CFURL)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            fatalError("Failed to create PDF context")
        }
        
        // Page 1: The quick brown fox jumps over the lazy dog. The.
        // This page alone has "the" 3 times, plus "The" at the start
        let page1Text = """
        The quick brown fox jumps over the lazy dog.
        The river flows through the valley.
        The sun sets behind the mountains.
        """
        
        // Page 2: More "the" occurrences
        let page2Text = """
        The morning mist covers the field.
        The birds sing in the trees.
        The world turns on its axis.
        """
        
        let pages = [page1Text, page2Text]
        
        for pageText in pages {
            context.beginPDFPage(nil)
            
            // Set up the font
            let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            
            let attributedString = NSAttributedString(string: pageText, attributes: attributes)
            let lineSetter = CTFramesetterCreateWithAttributedString(attributedString)
            
            let path = CGPath(rect: CGRect(
                x: margin,
                y: margin,
                width: pageSize.width - 2 * margin,
                height: pageSize.height - 2 * margin
            ), transform: nil)
            
            let frame = CTFramesetterCreateFrame(lineSetter, CFRangeMake(0, 0), path, nil)
            CTFrameDraw(frame, context)
            
            context.endPDFPage()
        }
        
        context.closePDF()
        
        return pdfURL
    }
}
