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
        
        // Check for --open-pdf argument (used by XCTest to open a PDF on launch)
        let openPDFPath = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--open-pdf=") }
            .map { String($0.dropFirst("--open-pdf=".count)) }
        
        // Check for --show-search argument (used by XCTest to show search bar)
        // Check for --search keyword argument (pre-fills search field with keyword)
        // Note: both are now handled in MainWindowView after PDF loads.
        
        if isUITesting {
            // Disable auto-reopen so the app shows RecentFilesView instead of auto-loading a PDF.
            WindowStateManager.shared.autoReopenLastDocument = false

            // Post --open-pdf notification after a short delay so that MainWindowView.onAppear
            // has time to create the DocumentViewModel first. Without the delay, the notification
            // fires before docVM exists and the PDF open request is silently dropped.
            if let path = openPDFPath {
                let url = URL(fileURLWithPath: path)
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    NotificationCenter.default.post(name: .openPDFURL, object: url)
                }
            }

            // Show search bar immediately if --show-search is passed.
            let showSearch = ProcessInfo.processInfo.arguments.contains("--show-search")
            if showSearch {
                NotificationCenter.default.post(name: .showSearchBar, object: nil)
            }

            // Handle --trigger-search argument: post setSearchKeyword after a delay
            // (delay ensures PDF has loaded and pdfView is set).
            let triggerSearch = ProcessInfo.processInfo.arguments
                .first { $0.hasPrefix("--trigger-search=") }
                .map { String($0.dropFirst("--trigger-search=".count)) }
            if let keyword = triggerSearch {
                Task { @MainActor in
                    // Wait for PDF to load + PDFViewWrapper to set pdfView.
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    NotificationCenter.default.post(
                        name: Notification.Name("setSearchKeyword"),
                        object: keyword
                    )
                }
            }

            // Note: --show-search and --search are handled in MainWindowView.onChange
            // after the PDF loads, guaranteeing searchVM.pdfView is set.

            // Explicitly activate the app so XCTest doesn't time out waiting for "Active" state.
            // Delay by 2s to let SwiftUI's WindowGroup fully create the NSWindow first.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    /// Forces the accessibility system to publish the app's accessibility tree.
    /// Minimal accessibility initialization for XCTest compatibility.
    /// Avoids aggressive NSAccessibility.post() calls that can block XCTest activation.
    private func initializeAccessibility() {
        // Just access keyWindow to publish accessibility tree without posting notifications
        _ = NSApp.keyWindow
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

