import PDFVeCore
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowStateObserver: Any?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if running in UITesting mode (skip delay for faster test startup)
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        
        if isUITesting {
            // UITesting: wait for SwiftUI window creation before initializing accessibility
            // This ensures the accessibility tree is published after the views exist
            Task { @MainActor in
                // Wait for SwiftUI views to be created
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Force accessibility tree initialization for XCTest compatibility
                // This posts notifications that trigger SwiftUI to publish its accessibility tree
                self.initializeAccessibility()
                
                // Restore window state
                self.restoreWindowState()
            }
        } else {
            // Normal mode: delay to allow SwiftUI window creation to complete
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                self.restoreWindowState()
            }
        }
    }
    
    /// Forces the accessibility system to publish the app's accessibility tree.
    /// This resolves "Application has not loaded accessibility" errors when XCTest
    /// launches the app and tries to access accessibility APIs immediately.
    private func initializeAccessibility() {
        // Get the process identifier for the current application
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // Create the application accessibility element
        // This forces the accessibility system to create the app's accessibility tree
        let appElement = AXUIElementCreateApplication(pid)
        
        // Post layout changed notification to force the accessibility system to re-query the tree
        // This is crucial for SwiftUI apps as it triggers the system to look for accessibility elements
        NSAccessibility.post(
            element: appElement as Any,
            notification: .layoutChanged
        )
        
        // Also post window notifications to ensure window accessibility is published
        if let keyWindow = NSApp.keyWindow {
            NSAccessibility.post(
                element: keyWindow as Any,
                notification: .windowResized
            )
            NSAccessibility.post(
                element: keyWindow as Any,
                notification: .windowMoved
            )
        }
        
        // Post application activated notification as well
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .applicationActivated
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowState()
    }

    private func restoreWindowState() {
        guard let window = NSApp.keyWindow else { return }

        let wsm = WindowStateManager.shared

        // 恢复窗口尺寸
        if let savedSize = wsm.savedWindowSize {
            window.setContentSize(savedSize)
        }

        // 恢复窗口位置
        if let savedOrigin = wsm.savedWindowOrigin {
            window.setFrameOrigin(savedOrigin)
        }
    }

    private func saveWindowState() {
        guard let window = NSApp.keyWindow else { return }
        WindowStateManager.shared.saveWindowState(frame: window.frame)
    }
}

extension AppDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .openPDFURL,
                object: url
            )
        }
    }
}

