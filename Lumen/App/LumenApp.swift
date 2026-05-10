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

struct DistractionFreeKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var isDistractionFree: Binding<Bool>? {
        get { self[DistractionFreeKey.self] }
        set { self[DistractionFreeKey.self] = newValue }
    }
}

struct SidebarVisibleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var sidebarVisible: Binding<Bool>? {
        get { self[SidebarVisibleKey.self] }
        set { self[SidebarVisibleKey.self] = newValue }
    }
}

struct DocumentViewModelKey: FocusedValueKey {
    typealias Value = DocumentViewModel
}

extension FocusedValues {
    var docVM: DocumentViewModel? {
        get { self[DocumentViewModelKey.self] }
        set { self[DocumentViewModelKey.self] = newValue }
    }
}

extension Notification.Name {
    static let exportAnnotations = Notification.Name("exportAnnotations")
    static let showPreferences = Notification.Name("showPreferences")
}

@main
struct PDF_VeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .modelContainer(persistence.container)
        // 使用统一工具栏样式，减少标题栏高度
        .windowToolbarStyle(.unified)
        .commands {
            PDFVeCommands()
        }
    }
}

struct PDFVeCommands: Commands {
    @FocusedValue(\.docVM) var docVM
    @FocusedValue(\.readerVM) var readerVM
    @FocusedValue(\.searchVM) var searchVM
    @FocusedValue(\.isDistractionFree) var isDistractionFree
    @FocusedValue(\.sidebarVisible) var sidebarVisible

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开…") {
                Task { await docVM?.showOpenPanel() }
            }
            .keyboardShortcut("o")
            Divider()
            Button("导出标注为文本…") {
                NotificationCenter.default.post(name: .exportAnnotations, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(docVM?.currentDocument == nil)
            Divider()
            Button("打印…") {
                readerVM?.printDocument()
            }
            .keyboardShortcut("p")
            .disabled(readerVM?.pdfView?.document == nil)
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
            Toggle("侧栏", isOn: sidebarVisible ?? .constant(true))
                .keyboardShortcut("t")
                .disabled(readerVM == nil)
            Toggle("专注阅读模式", isOn: isDistractionFree ?? .constant(false))
                .keyboardShortcut("\\")
                .disabled(readerVM == nil)
            Divider()
            // 阅读模式子菜单
            Menu("阅读模式") {
                ForEach(ReaderViewModel.ReadingMode.allCases, id: \.self) { mode in
                    Button {
                        readerVM?.setReadingMode(mode)
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if readerVM?.readingMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            // 显示模式子菜单
            Menu("显示模式") {
                ForEach(ReaderViewModel.DisplayMode.allCases, id: \.self) { mode in
                    Button {
                        readerVM?.setDisplayMode(mode)
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if readerVM?.displayMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
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
        CommandGroup(after: .appSettings) {
            Button("偏好设置…") {
                NotificationCenter.default.post(name: .showPreferences, object: nil)
            }
            .keyboardShortcut(",")
        }
    }
}
