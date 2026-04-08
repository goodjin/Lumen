import PDFKit
import SwiftUI

public extension Notification.Name {
    static let openPDFURL = Notification.Name("openPDFURL")
    static let restoreReadingState = Notification.Name("restoreReadingState")
}

@MainActor
@Observable
public class DocumentViewModel {
    private let fileService: FileService

    // 文档状态（STATE-001）
    public enum DocumentState {
        case idle
        case loading
        case loaded(PDFDocument, URL)
        case error(Error)
    }

    public var state: DocumentState = .idle
    public var recentDocuments: [DocumentRecord] = []
    public var currentURL: URL? {
        if case .loaded(_, let url) = state { return url }
        return nil
    }
    public var currentDocument: PDFDocument? {
        if case .loaded(let doc, _) = state { return doc }
        return nil
    }

    public init(fileService: FileService) {
        self.fileService = fileService
        recentDocuments = fileService.recentDocuments()
        NotificationCenter.default.addObserver(
            forName: .openPDFURL,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let url = notification.object as? URL else { return }
            Task { await self?.open(url: url) }
        }
    }

    // 打开文件（菜单/拖拽调用）
    public func open(url: URL) async {
        state = .loading
        do {
            let doc = try await fileService.openDocument(at: url)
            state = .loaded(doc, url)
            recentDocuments = fileService.recentDocuments()
            updateWindowTitle()

            // T-02-04b: 读取并应用阅读位置（Rule-002）
            if let readingState = fileService.readingState(for: url) {
                NotificationCenter.default.post(
                    name: .restoreReadingState,
                    object: nil,
                    userInfo: ["page": readingState.page, "zoom": readingState.zoom]
                )
            }
        } catch {
            state = .error(error)
        }
    }

    // 打开最近文件
    public func openRecent(_ record: DocumentRecord) async {
        state = .loading
        do {
            let doc = try await fileService.openRecentDocument(record)
            let url = URL(fileURLWithPath: record.filePath)
            state = .loaded(doc, url)
            recentDocuments = fileService.recentDocuments()
            updateWindowTitle()
        } catch {
            state = .error(error)
            recentDocuments = fileService.recentDocuments() // 刷新（失效记录已移除）
        }
    }

    // 关闭文档（保存阅读状态，Rule-002）
    public func close(currentPage: Int, zoomLevel: Double) {
        if let url = currentURL {
            fileService.closeDocument(at: url, currentPage: currentPage, zoomLevel: zoomLevel)
        }
        state = .idle
        updateWindowTitle()
    }

    // 显示文件选择对话框
    public func showOpenPanel() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK,
              let url = panel.url else { return }
        await open(url: url)
    }

    // 更新窗口标题
    public func updateWindowTitle() {
        if case .loaded(_, let url) = state {
            NSApp.keyWindow?.title = "Lumen - \(url.lastPathComponent)"
        } else {
            NSApp.keyWindow?.title = "Lumen"
        }
    }
}
