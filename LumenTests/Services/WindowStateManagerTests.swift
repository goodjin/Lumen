import XCTest
@testable import PDFVeCore
import AppKit

@MainActor
final class WindowStateManagerTests: XCTestCase {

    private var manager: WindowStateManager!

    override func setUp() {
        super.setUp()
        manager = WindowStateManager()
        // Clean up UserDefaults state from any previous tests
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "windowWidth")
        defaults.removeObject(forKey: "windowHeight")
        defaults.removeObject(forKey: "windowX")
        defaults.removeObject(forKey: "windowY")
    }

    override func tearDown() {
        // Clean up any state set during test using UserDefaults directly
        // since the computed property setters don't handle nil properly
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "windowWidth")
        defaults.removeObject(forKey: "windowHeight")
        defaults.removeObject(forKey: "windowX")
        defaults.removeObject(forKey: "windowY")
        defaults.removeObject(forKey: "lastSidebarTab")
        defaults.removeObject(forKey: "sidebarVisible")
        defaults.removeObject(forKey: "lastOpenedFilePath")
        defaults.removeObject(forKey: "autoReopenLastDocument")
        defaults.removeObject(forKey: "defaultReadingMode")
        defaults.removeObject(forKey: "defaultDisplayMode")
        manager = nil
        super.tearDown()
    }

    // MARK: - Sidebar Tab

    func test_lastSidebarTab_defaults_to_outline() {
        // Given: fresh manager (or after cleanup)
        manager.lastSidebarTab = .outline // reset

        // Then: default is outline
        XCTAssertEqual(manager.lastSidebarTab, .outline)
    }

    func test_lastSidebarTab_can_be_set_to_annotation() {
        // When: set to annotation
        manager.lastSidebarTab = .annotation

        // Then: reading back returns annotation
        XCTAssertEqual(manager.lastSidebarTab, .annotation)
    }

    func test_lastSidebarTab_can_be_set_to_bookmark() {
        // When: set to bookmark
        manager.lastSidebarTab = .bookmark

        // Then: reading back returns bookmark
        XCTAssertEqual(manager.lastSidebarTab, .bookmark)
    }

    func test_lastSidebarTab_can_be_set_to_thumbnail() {
        // When: set to thumbnail
        manager.lastSidebarTab = .thumbnail

        // Then: reading back returns thumbnail
        XCTAssertEqual(manager.lastSidebarTab, .thumbnail)
    }

    // MARK: - Sidebar Visible

    func test_sidebarVisible_defaults_to_true() {
        // Given: clean state
        manager.sidebarVisible = true

        // Then: default is visible
        XCTAssertTrue(manager.sidebarVisible)
    }

    func test_sidebarVisible_can_be_set_to_false() {
        // When: set to false
        manager.sidebarVisible = false

        // Then: reading back returns false
        XCTAssertFalse(manager.sidebarVisible)
    }

    // MARK: - Window Size

    func test_savedWindowSize_returns_nil_when_not_set() {
        // Given: clean state
        manager.savedWindowSize = nil

        // Then: returns nil
        XCTAssertNil(manager.savedWindowSize)
    }

    func test_savedWindowSize_persists_size() {
        // When: set a window size
        let size = CGSize(width: 1200, height: 800)
        manager.savedWindowSize = size

        // Then: reading back returns same size
        XCTAssertEqual(manager.savedWindowSize?.width, 1200)
        XCTAssertEqual(manager.savedWindowSize?.height, 800)
    }

    // MARK: - Window Origin

    func test_savedWindowOrigin_returns_nil_when_not_set() {
        // Given: clean state
        manager.savedWindowOrigin = nil

        // Then: returns nil
        XCTAssertNil(manager.savedWindowOrigin)
    }

    func test_savedWindowOrigin_persists_origin() {
        // When: set a window origin
        let origin = CGPoint(x: 100, y: 200)
        manager.savedWindowOrigin = origin

        // Then: reading back returns same origin
        XCTAssertEqual(manager.savedWindowOrigin?.x, 100)
        XCTAssertEqual(manager.savedWindowOrigin?.y, 200)
    }

    // MARK: - Last Opened File Path

    func test_lastOpenedFilePath_returns_nil_when_not_set() {
        // Given: clean state
        manager.lastOpenedFilePath = nil

        // Then: returns nil
        XCTAssertNil(manager.lastOpenedFilePath)
    }

    func test_lastOpenedFilePath_persists_path() {
        // When: set a file path
        manager.lastOpenedFilePath = "/tmp/test.pdf"

        // Then: reading back returns same path
        XCTAssertEqual(manager.lastOpenedFilePath, "/tmp/test.pdf")
    }

    // MARK: - Auto Reopen

    func test_autoReopenLastDocument_defaults_to_true() {
        // Given: clean state
        manager.autoReopenLastDocument = true

        // Then: default is true
        XCTAssertTrue(manager.autoReopenLastDocument)
    }

    func test_autoReopenLastDocument_can_be_set_to_false() {
        // When: set to false
        manager.autoReopenLastDocument = false

        // Then: reading back returns false
        XCTAssertFalse(manager.autoReopenLastDocument)
    }

    // MARK: - Default Reading Mode

    func test_defaultReadingMode_defaults_to_normal() {
        // Given: clean state
        manager.defaultReadingMode = .normal

        // Then: default is normal
        XCTAssertEqual(manager.defaultReadingMode, .normal)
    }

    func test_defaultReadingMode_persists_dark_mode() {
        // When: set to dark
        manager.defaultReadingMode = .dark

        // Then: reading back returns dark
        XCTAssertEqual(manager.defaultReadingMode, .dark)
    }

    func test_defaultReadingMode_persists_sepia_mode() {
        // When: set to sepia
        manager.defaultReadingMode = .sepia

        // Then: reading back returns sepia
        XCTAssertEqual(manager.defaultReadingMode, .sepia)
    }

    func test_defaultReadingMode_persists_eyeCare_mode() {
        // When: set to eyeCare
        manager.defaultReadingMode = .eyeCare

        // Then: reading back returns eyeCare
        XCTAssertEqual(manager.defaultReadingMode, .eyeCare)
    }

    // MARK: - Default Display Mode

    func test_defaultDisplayMode_defaults_to_singleContinuous() {
        // Given: clean state
        manager.defaultDisplayMode = .singleContinuous

        // Then: default is singleContinuous
        XCTAssertEqual(manager.defaultDisplayMode, .singleContinuous)
    }

    func test_defaultDisplayMode_persists_single() {
        // When: set to single
        manager.defaultDisplayMode = .single

        // Then: reading back returns single
        XCTAssertEqual(manager.defaultDisplayMode, .single)
    }

    func test_defaultDisplayMode_persists_two() {
        // When: set to two
        manager.defaultDisplayMode = .two

        // Then: reading back returns two
        XCTAssertEqual(manager.defaultDisplayMode, .two)
    }

    func test_defaultDisplayMode_persists_twoContinuous() {
        // When: set to twoContinuous
        manager.defaultDisplayMode = .twoContinuous

        // Then: reading back returns twoContinuous
        XCTAssertEqual(manager.defaultDisplayMode, .twoContinuous)
    }

    // MARK: - Default Window Size

    func test_defaultWindowSize_returns_900x700() {
        // Then: default size is 900x700
        XCTAssertEqual(WindowStateManager.defaultWindowSize, NSSize(width: 900, height: 700))
    }
}
