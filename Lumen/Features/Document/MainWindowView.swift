import PDFVeCore
import SwiftUI
import PDFKit
import SwiftData
import AppKit

struct MainWindowView: View {
    @Environment(DocumentViewModel.self) var docVM
    @Environment(\.modelContext) private var modelContext
    @State private var readerVM = ReaderViewModel()
    @State private var outlineVM = OutlineViewModel()
    @State private var searchVM = SearchViewModel()
    @State private var annotationVM: AnnotationViewModel?
    @State private var sidebarVM: SidebarViewModel?
    @State private var isSidebarVisible = true

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
        .onChange(of: docVM.currentDocument) { _, newDoc in
            if let doc = newDoc, let url = docVM.currentURL {
                readerVM = ReaderViewModel()
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
        HSplitView {
            // 侧栏区域
            if isSidebarVisible, let sidebarVM {
                SidebarView(outlineVM: outlineVM, sidebarVM: sidebarVM, readerVM: readerVM, document: doc)
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
                PDFReaderView(document: doc, readerVM: readerVM, annotationVM: annotationVM)
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
            }
            .focusedValue(\.readerVM, readerVM)
            .focusedValue(\.searchVM, searchVM)
            .focusedValue(\.annotationVM, annotationVM)
            .onDisappear {
                docVM.close(currentPage: readerVM.currentPage, zoomLevel: readerVM.zoomLevel)
            }
        }
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
