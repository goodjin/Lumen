import PDFVeCore
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowStateObserver: Any?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 延迟获取窗口并恢复状态，因为 SwiftUI 窗口创建是异步的
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            self.restoreWindowState()
        }
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

