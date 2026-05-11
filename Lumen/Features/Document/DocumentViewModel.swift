import PDFKit
import SwiftUI
import Combine

public extension Notification.Name {
    static let openPDFURL = Notification.Name("openPDFURL")
    static let restoreReadingState = Notification.Name("restoreReadingState")
    /// Posted when a PDF document finishes loading successfully.
    static let documentDidLoad = Notification.Name("documentDidLoad")
}

@MainActor
@Observable
public class DocumentViewModel: Equatable {
    public static func == (lhs: DocumentViewModel, rhs: DocumentViewModel) -> Bool {
        lhs.state.isEqual(to: rhs.state)
    }

    private let fileService: FileService

    // MARK: - Document State

    /// Document state (STATE-001)
    public enum DocumentState {
        case idle
        case loading
        case loaded(PDFDocument, URL)
        case error(Error)

        public func isEqual(to other: DocumentState) -> Bool {
            switch (self, other) {
            case (.idle, .idle): return true
            case (.loading, .loading): return true
            case (.loaded, .loaded): return true
            case (.error, .error): return true
            default: return false
            }
        }
    }

    public var state: DocumentState = .idle {
        didSet {
            if case .loaded(let doc, _) = state {
                loadedDocument = doc
                onDocumentLoaded?(doc)
                NotificationCenter.default.post(
                    name: .documentDidLoad,
                    object: nil,
                    userInfo: ["document": doc]
                )
            }
        }
    }

    /// Set by MainWindowView to observe when PDF finishes loading.
    public var onDocumentLoaded: ((PDFDocument) -> Void)?

    /// Triggers onChange in SwiftUI views when PDF loads.
    public var loadedDocument: PDFDocument?

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

    // MARK: - File Operations

    /// Open a PDF file (API-001)
    public func open(url: URL) async {
        state = .loading
        do {
            let doc = try await fileService.openDocument(at: url)
            state = .loaded(doc, url)
            recentDocuments = fileService.recentDocuments()
            updateWindowTitle()
            WindowStateManager.shared.lastOpenedFilePath = url.path
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

    /// Open a recent document (API-004)
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
            recentDocuments = fileService.recentDocuments()
        }
    }

    /// Close the current document (API-002)
    public func close(currentPage: Int, zoomLevel: Double) {
        if let url = currentURL {
            fileService.closeDocument(at: url, currentPage: currentPage, zoomLevel: zoomLevel)
        }
        state = .idle
        updateWindowTitle()
    }

    /// Save reading state without closing document
    public func saveReadingState(currentPage: Int, zoomLevel: Double) {
        if let url = currentURL {
            fileService.closeDocument(at: url, currentPage: currentPage, zoomLevel: zoomLevel)
        }
    }

    /// Show open panel (API-001)
    public func showOpenPanel() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK,
              let url = panel.url else { return }
        await open(url: url)
    }

    /// Remove a recent document record
    public func removeRecent(_ record: DocumentRecord) {
        try? fileService.removeRecent(filePath: record.filePath)
        recentDocuments = fileService.recentDocuments()
    }

    /// Clear all recent documents
    public func clearRecentDocuments() {
        fileService.clearAllRecent()
        recentDocuments = []
    }

    /// Update window title
    private func updateWindowTitle() {
        if case .loaded(_, let url) = state {
            NSApp.keyWindow?.title = "Lumen - \(url.lastPathComponent)"
        } else {
            NSApp.keyWindow?.title = "Lumen"
        }
    }
}
