import PDFVeCore
import SwiftUI
import SwiftData

// FocusedValue key 供 Commands 访问 ReaderViewModel（AC-003-02~04）
struct ReaderViewModelKey: FocusedValueKey {
    typealias Value = ReaderViewModel
}

extension FocusedValues {
    var readerVM: ReaderViewModel? {
        get { self[ReaderViewModelKey.self] }
        set { self[ReaderViewModelKey.self] = newValue }
    }
}

struct SearchViewModelKey: FocusedValueKey {
    typealias Value = SearchViewModel
}

extension FocusedValues {
    var searchVM: SearchViewModel? {
        get { self[SearchViewModelKey.self] }
        set { self[SearchViewModelKey.self] = newValue }
    }
}

struct AnnotationViewModelKey: FocusedValueKey {
    typealias Value = AnnotationViewModel
}

extension FocusedValues {
    var annotationVM: AnnotationViewModel? {
        get { self[AnnotationViewModelKey.self] }
        set { self[AnnotationViewModelKey.self] = newValue }
    }
}

extension Notification.Name {
    static let exportAnnotations = Notification.Name("exportAnnotations")
}

@main
struct PDF_VeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let persistence = PersistenceController.shared
    private let docVM: DocumentViewModel

    init() {
        let context = persistence.container.mainContext
        let docRepo = DocumentRepository(context: context)
        let fileService = FileService(docRepo: docRepo)
        docVM = DocumentViewModel(fileService: fileService)
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(docVM)
        }
        .modelContainer(persistence.container)
        // 使用统一工具栏样式，减少标题栏高度
        .windowToolbarStyle(.unified)
        .commands {
            PDFVeCommands(docVM: docVM)
        }
    }
}

struct PDFVeCommands: Commands {
    let docVM: DocumentViewModel
    @FocusedValue(\.readerVM) var readerVM
    @FocusedValue(\.searchVM) var searchVM

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开…") {
                Task { await docVM.showOpenPanel() }
            }
            .keyboardShortcut("o")
            Divider()
            Button("导出标注为文本…") {
                NotificationCenter.default.post(name: .exportAnnotations, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(docVM.currentDocument == nil)
        }
        CommandGroup(after: .textEditing) {
            Button("查找…") {
                searchVM?.isSearchBarVisible = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(searchVM == nil)
            Button("下一个") { searchVM?.nextMatch() }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(searchVM == nil)
            Button("上一个") { searchVM?.previousMatch() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(searchVM == nil)
        }
        CommandMenu("视图") {
            Button("实际大小") { readerVM?.setZoom(1.0) }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(readerVM == nil)
            Button("适合宽度") { readerVM?.setZoomMode(.fitWidth) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(readerVM == nil)
            Button("适合页面") { readerVM?.setZoomMode(.fitPage) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(readerVM == nil)
            Divider()
            Button("放大") { readerVM?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(readerVM == nil)
            Button("缩小") { readerVM?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(readerVM == nil)
        }
    }
}
