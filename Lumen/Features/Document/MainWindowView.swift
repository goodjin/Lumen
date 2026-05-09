import PDFVeCore
import SwiftUI
import PDFKit
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct MainWindowView: View {
    @Environment(DocumentViewModel.self) var docVM
    @Environment(\.modelContext) private var modelContext
    @State private var readerVM = ReaderViewModel()
    @State private var outlineVM = OutlineViewModel()
    @State private var searchVM = SearchViewModel()
    @State private var annotationVM: AnnotationViewModel?
    @State private var sidebarVM: SidebarViewModel?
    @State private var isSidebarVisible = true
    @State private var showDocumentInfo = false
    @State private var isDistractionFree = false
    @State private var isDropTargeted = false
    @State private var thumbnailProvider = ThumbnailProvider()

    var body: some View {
        Group {
            switch docVM.state {
            case .idle:
                RecentFilesView()
            case .loading:
                ProgressView("正在打开…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let doc, let url):
                readerContent(doc: doc, url: url)
            case .error(let error):
                ContentUnavailableView(
                    "无法打开文件",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // 自动恢复上次打开的文档
            if case .idle = docVM.state,
               let lastPath = WindowStateManager.shared.lastOpenedFilePath,
               FileManager.default.fileExists(atPath: lastPath) {
                Task { await docVM.open(url: URL(fileURLWithPath: lastPath)) }
            }
        }
        .onChange(of: docVM.currentDocument) { _, newDoc in
            if let doc = newDoc, let url = docVM.currentURL {
                readerVM = ReaderViewModel()
                readerVM.clearHistory()
                outlineVM = OutlineViewModel()
                outlineVM.loadOutline(from: doc)
                searchVM = SearchViewModel()
                let annRepo = AnnotationRepository(context: modelContext)
                let annService = AnnotationService(repo: annRepo)
                let annVM = AnnotationViewModel(service: annService, repo: annRepo)
                annVM.loadAnnotations(for: url.path)
                annotationVM = annVM
                // SidebarViewModel（P-08）
                let bookmarkRepo = BookmarkRepository(context: modelContext)
                let bookmarkSvc = BookmarkService(repository: bookmarkRepo)
                sidebarVM = SidebarViewModel(
                    bookmarkService: bookmarkSvc,
                    readerVM: readerVM,
                    annotationVM: annVM
                )
                sidebarVM?.loadForDocument(url.path)
            } else {
                readerVM = ReaderViewModel()
                outlineVM = OutlineViewModel()
                searchVM = SearchViewModel()
                annotationVM = nil
                sidebarVM = nil
                Task { await thumbnailProvider.clearCache() }
            }
        }
        // Cmd+T 侧栏显隐（AC-004-06）
        .onKeyPress(.init("t"), phases: .down) { event in
            guard event.modifiers.contains(.command) else { return .ignored }
            isSidebarVisible.toggle()
            return .handled
        }
        // Cmd+B 切换书签（AC-012-01）
        .onKeyPress(.init("b"), phases: .down) { event in
            guard event.modifiers.contains(.command) else { return .ignored }
            sidebarVM?.toggleBookmark()
            return .handled
        }
        // Cmd+[ 后退 / Cmd+] 前进
        .onKeyPress(.init("["), phases: .down) { event in
            guard event.modifiers.contains(.command) else { return .ignored }
            readerVM.goBack()
            return .handled
        }
        .onKeyPress(.init("]"), phases: .down) { event in
            guard event.modifiers.contains(.command) else { return .ignored }
            readerVM.goForward()
            return .handled
        }
        // Cmd+\ 专注阅读模式
        .onKeyPress(.init("\\"), phases: .down) { event in
            guard event.modifiers.contains(.command) else { return .ignored }
            isDistractionFree.toggle()
            return .handled
        }
        // Esc 退出专注模式
        .onKeyPress(.escape) {
            if isDistractionFree {
                isDistractionFree = false
                return .handled
            }
            return .ignored
        }
        // 导出标注（AC-016-01~04）
        .onReceive(NotificationCenter.default.publisher(for: .exportAnnotations)) { _ in
            guard case .loaded(_, let url) = docVM.state,
                  annotationVM != nil else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + "-标注"
            Task {
                guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK,
                      let saveURL = panel.url else { return }
                let annRepo = AnnotationRepository(context: modelContext)
                let exportSvc = ExportService(annotationRepo: annRepo)
                do {
                    try exportSvc.exportToFile(for: url.path, saveTo: saveURL)
                } catch ExportError.noAnnotations {
                    showAlert(message: "当前文档无标注内容")
                } catch {
                    showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    @ViewBuilder
    private func readerContent(doc: PDFDocument, url: URL) -> some View {
        Group {
            if isDistractionFree {
                // 专注模式：只显示 PDF 内容 + 浮动退出按钮
                ZStack(alignment: .topTrailing) {
                    PDFReaderView(document: doc, readerVM: readerVM, annotationVM: annotationVM, onSearchSelection: { text in
                        searchVM.keyword = text
                        searchVM.isSearchBarVisible = true
                        searchVM.performSearch(in: doc)
                    })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            searchVM.pdfView = readerVM.pdfView
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .restoreReadingState)) { notification in
                            if let page = notification.userInfo?["page"] as? Int {
                                readerVM.goToPage(page)
                            }
                            if let zoom = notification.userInfo?["zoom"] as? Double {
                                readerVM.setZoom(zoom)
                            }
                        }

                    // 浮动退出按钮
                    Button {
                        isDistractionFree = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            // hover 时 opacity 通过条件控制
                        }
                    }
                }
                .focusedValue(\.readerVM, readerVM)
                .focusedValue(\.searchVM, searchVM)
                .focusedValue(\.annotationVM, annotationVM)
                .focusedValue(\.isDistractionFree, $isDistractionFree)
                .toolbar(.hidden, for: .windowToolbar)
            } else {
                // 正常模式
                HSplitView {
                    // 侧栏区域
                    if isSidebarVisible, let sidebarVM {
                        SidebarView(outlineVM: outlineVM, sidebarVM: sidebarVM, readerVM: readerVM, document: doc, thumbnailProvider: thumbnailProvider)
                            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
                    }

                    // 主内容区域
                    VStack(spacing: 0) {
                        // UI-Layout-001: 工具栏高度固定 44pt
                        // 合并主工具栏和标注工具栏到一行
                        HStack(spacing: 12) {
                            ReaderToolbarView(readerVM: readerVM)

                            Divider()

                            // 标注工具（AC-006~010）- 内嵌到主工具栏
                            if let annotationVM {
                                AnnotationToolbar(annotationVM: annotationVM)
                                    .frame(height: 32)
                            }

                            Spacer()

                            // 书签按钮（AC-012-02）
                            if let sidebarVM {
                                Button {
                                    sidebarVM.toggleBookmark()
                                } label: {
                                    Image(systemName: sidebarVM.isCurrentPageBookmarked
                                        ? "bookmark.fill" : "bookmark")
                                }
                                .help(sidebarVM.isCurrentPageBookmarked ? "移除书签" : "添加书签 (⌘B)")
                            }
                            Button {
                                isSidebarVisible.toggle()
                            } label: {
                                Image(systemName: "sidebar.left")
                            }
                            .help("显示/隐藏侧栏 (⌘T)")
                            Button {
                                showDocumentInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                            .help("文档属性")
                            // 专注模式按钮
                            Button {
                                isDistractionFree = true
                            } label: {
                                Image(systemName: "eye")
                            }
                            .help("专注阅读模式 (⌘\\)")
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44, alignment: .center)

                        Divider()

                        // 搜索栏（如果可见）
                        if searchVM.isSearchBarVisible {
                            SearchBarView(searchVM: searchVM, document: doc)
                            Divider()
                        }

                        // PDF 阅读区 - 撑满剩余高度
                        ZStack(alignment: .bottom) {
                            PDFReaderView(document: doc, readerVM: readerVM, annotationVM: annotationVM, onSearchSelection: { text in
                                searchVM.keyword = text
                                searchVM.isSearchBarVisible = true
                                searchVM.performSearch(in: doc)
                            })
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onAppear {
                                    searchVM.pdfView = readerVM.pdfView
                                }
                                // T-02-04b: 监听并应用阅读位置恢复（Rule-002）
                                .onReceive(NotificationCenter.default.publisher(for: .restoreReadingState)) { notification in
                                    if let page = notification.userInfo?["page"] as? Int {
                                        readerVM.goToPage(page)
                                    }
                                    if let zoom = notification.userInfo?["zoom"] as? Double {
                                        readerVM.setZoom(zoom)
                                    }
                                }

                            // 阅读进度条
                            if readerVM.totalPages > 0 {
                                ReadingProgressBar(progress: Double(readerVM.currentPage) / Double(readerVM.totalPages))
                            }
                        }

                        Divider()

                        // 底部状态栏
                        StatusBarView(readerVM: readerVM, fileURL: url)
                    }
                    .focusedValue(\.readerVM, readerVM)
                    .focusedValue(\.searchVM, searchVM)
                    .focusedValue(\.annotationVM, annotationVM)
                    .focusedValue(\.isDistractionFree, $isDistractionFree)
                    .sheet(isPresented: $showDocumentInfo) {
                        DocumentInfoView(document: doc, fileURL: url)
                    }
                    .onDisappear {
                        docVM.close(currentPage: readerVM.currentPage, zoomLevel: readerVM.zoomLevel)
                        Task { await thumbnailProvider.clearCache() }
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(4)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
            guard let data = item as? Data,
                  let droppedURL = URL(dataRepresentation: data, relativeTo: nil),
                  droppedURL.pathExtension.lowercased() == "pdf" else { return }
            Task { @MainActor in
                // 保存当前阅读状态再切换文档
                docVM.saveReadingState(currentPage: readerVM.currentPage, zoomLevel: readerVM.zoomLevel)
                await docVM.open(url: droppedURL)
            }
        }
        return true
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "导出失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
