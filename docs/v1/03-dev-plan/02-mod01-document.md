# P-02: MOD-01 文件管理模块

## 文档信息

- **计划编号**: P-02
- **批次**: 第1批
- **对应架构**: docs/v1/02-architecture/03-mod01-document.md
- **优先级**: P0
- **前置依赖**: P-01（数据层）

---

## 模块职责

实现文件打开、最近文件管理、阅读位置记忆。对应 PRD: FR-001, FR-015, Rule-002, Rule-003, Rule-004。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-02-01 | FileService | 1 | ~120 | P-01 |
| T-02-02 | DocumentViewModel | 1 | ~100 | T-02-01 |
| T-02-03 | RecentFilesView（启动页） | 1 | ~80 | T-02-02 |
| T-02-04 | MainWindowView 骨架 + 菜单命令 | 2 | ~100 | T-02-02 |
| T-02-04b | 读取并应用阅读位置（Rule-002） | 1 | ~40 | T-02-04 |
| T-02-05 | 拖拽打开 + 文件关联注册 | 2 | ~60 | T-02-04 |

---

## 详细任务定义

### T-02-01: FileService

**任务概述**: 实现文件打开校验、最近文件 CRUD、阅读位置读写。

**输出文件**: `PDF-Ve/Features/Document/FileService.swift`

**实现要求**:

```swift
import PDFKit
import Foundation

@MainActor
class FileService {
    private let docRepo: DocumentRepository

    init(docRepo: DocumentRepository) {
        self.docRepo = docRepo
    }

    // API-001: 打开文件（校验 + 记录）
    func openDocument(at url: URL) async throws -> PDFDocument {
        guard url.pathExtension.lowercased() == "pdf" else {
            throw FileError.invalidPDF
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileError.notFound
        }
        guard let doc = PDFDocument(url: url) else {
            throw FileError.invalidPDF
        }
        try docRepo.recordOpen(
            filePath: url.path,
            fileName: url.lastPathComponent,
            pageCount: doc.pageCount
        )
        return doc
    }

    // API-002: 关闭时保存阅读状态（Rule-002）
    func closeDocument(at url: URL, currentPage: Int, zoomLevel: Double) {
        try? docRepo.updateReadingState(filePath: url.path, page: currentPage, zoom: zoomLevel)
    }

    // API-003: 获取最近文件列表
    func recentDocuments() -> [DocumentRecord] {
        (try? docRepo.fetchRecent()) ?? []
    }

    // API-004: 打开最近文件（路径校验，Rule-003）
    func openRecentDocument(_ record: DocumentRecord) async throws -> PDFDocument {
        guard FileManager.default.fileExists(atPath: record.filePath) else {
            try? docRepo.remove(filePath: record.filePath)
            throw FileError.notFoundRemoved
        }
        return try await openDocument(at: URL(fileURLWithPath: record.filePath))
    }

    // API-005: 获取上次阅读状态
    func readingState(for url: URL) -> (page: Int, zoom: Double)? {
        try? docRepo.readingState(for: url.path)
    }
}
```

**验收标准**:
- [ ] 非 PDF 文件抛 `FileError.invalidPDF`
- [ ] 文件不存在抛 `FileError.notFound`
- [ ] `openRecentDocument` 文件失效时从列表移除并抛 `FileError.notFoundRemoved`
- [ ] `closeDocument` 不抛异常（静默失败）

**依赖**: P-01（DocumentRepository）

---

### T-02-02: DocumentViewModel

**任务概述**: 管理当前打开的文档状态，驱动视图层。

**输出文件**: `PDF-Ve/Features/Document/DocumentViewModel.swift`

**实现要求**:

```swift
import PDFKit
import SwiftUI

@MainActor
@Observable
class DocumentViewModel {
    private let fileService: FileService

    // 文档状态（STATE-001）
    enum DocumentState {
        case idle
        case loading
        case loaded(PDFDocument, URL)
        case error(Error)
    }

    var state: DocumentState = .idle
    var recentDocuments: [DocumentRecord] = []
    var currentURL: URL? {
        if case .loaded(_, let url) = state { return url }
        return nil
    }
    var currentDocument: PDFDocument? {
        if case .loaded(let doc, _) = state { return doc }
        return nil
    }

    init(fileService: FileService) {
        self.fileService = fileService
        recentDocuments = fileService.recentDocuments()
    }

    // 打开文件（菜单/拖拽调用）
    func open(url: URL) async {
        state = .loading
        do {
            let doc = try await fileService.openDocument(at: url)
            state = .loaded(doc, url)
            recentDocuments = fileService.recentDocuments()
        } catch {
            state = .error(error)
        }
    }

    // 打开最近文件
    func openRecent(_ record: DocumentRecord) async {
        state = .loading
        do {
            let doc = try await fileService.openRecentDocument(record)
            let url = URL(fileURLWithPath: record.filePath)
            state = .loaded(doc, url)
            recentDocuments = fileService.recentDocuments()
        } catch {
            state = .error(error)
            recentDocuments = fileService.recentDocuments() // 刷新（失效记录已移除）
        }
    }

    // 关闭文档（保存阅读状态，Rule-002）
    func close(currentPage: Int, zoomLevel: Double) {
        if let url = currentURL {
            fileService.closeDocument(at: url, currentPage: currentPage, zoomLevel: zoomLevel)
        }
        state = .idle
    }

    // 显示文件选择对话框
    func showOpenPanel() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK,
              let url = panel.url else { return }
        await open(url: url)
    }
}
```

**验收标准**:
- [ ] `state` 枚举驱动视图切换（idle→loading→loaded/error）
- [ ] `recentDocuments` 在打开文件后刷新
- [ ] `close()` 正确调用 `fileService.closeDocument()`
- [ ] `showOpenPanel()` 过滤只显示 PDF 文件

**依赖**: T-02-01

---

### T-02-03: RecentFilesView（启动页）

**任务概述**: 实现应用启动时显示的最近文件列表页面。

**输出文件**: `PDF-Ve/Features/Document/RecentFilesView.swift`

**实现要求**:

```swift
import SwiftUI

struct RecentFilesView: View {
    @Environment(DocumentViewModel.self) var docVM

    var body: some View {
        VStack(spacing: 0) {
            // 标题区
            HStack {
                Text("PDF-Ve")
                    .font(.largeTitle.bold())
                Spacer()
                Button("打开文件…") {
                    Task { await docVM.showOpenPanel() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if docVM.recentDocuments.isEmpty {
                // 空状态
                ContentUnavailableView("没有最近打开的文件",
                    systemImage: "doc.text",
                    description: Text("点击「打开文件」选择 PDF"))
            } else {
                // 最近文件列表（AC-015-01）
                List(docVM.recentDocuments, id: \.filePath) { record in
                    RecentFileRow(record: record)
                        .onTapGesture {
                            Task { await docVM.openRecent(record) }
                        }
                }
            }
        }
        // 拖拽打开（AC-001-02）
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "pdf" else { return }
            Task { @MainActor in await docVM.open(url: url) }
        }
        return true
    }
}

struct RecentFileRow: View {
    let record: DocumentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.fileName)
                .font(.headline)
            Text(record.filePath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(record.lastOpenedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
```

**验收标准**:
- [ ] 最多显示 20 条最近文件（由 Repository 保证）
- [ ] 每条显示文件名、路径、最后打开时间（AC-015-03）
- [ ] 拖拽 PDF 到视图可触发打开
- [ ] 无最近文件时显示空状态提示

**依赖**: T-02-02

---

### T-02-04: MainWindowView 骨架 + 菜单命令

**任务概述**: 实现主窗口视图骨架（根据 DocumentState 切换 RecentFilesView / 阅读视图），添加「文件」菜单命令。

**输出文件**:
- `PDF-Ve/Features/Document/MainWindowView.swift`
- `PDF-Ve/App/PDF_VeApp.swift`（更新）

**实现要求**:

```swift
// MainWindowView.swift
import SwiftUI

struct MainWindowView: View {
    @Environment(DocumentViewModel.self) var docVM

    var body: some View {
        Group {
            switch docVM.state {
            case .idle:
                RecentFilesView()
            case .loading:
                ProgressView("正在打开…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let doc, _):
                // 占位，P-03 实现 PDFReaderView
                Text("PDF 已加载：\(doc.pageCount) 页")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let error):
                ContentUnavailableView(
                    "无法打开文件",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// PDF_VeApp.swift（更新，添加菜单）
// commands 中添加：
struct PDFVeCommands: Commands {
    @Environment(DocumentViewModel.self) var docVM

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开…") {
                Task { await docVM.showOpenPanel() }
            }
            .keyboardShortcut("o")
        }
    }
}
```

**验收标准**:
- [ ] 应用启动显示 RecentFilesView
- [ ] 打开文件后切换到加载中提示，成功后显示内容
- [ ] 菜单「文件 > 打开」(Cmd+O) 可触发文件选择

**依赖**: T-02-02, T-02-03

---

### T-02-04b: 读取并应用阅读位置（Rule-002）

**任务概述**: 实现文档打开后读取并恢复上次阅读位置（页码和缩放级别）。这是 Rule-002「记忆上次阅读位置」的读取端任务，与 T-02-01 的 `closeDocument` 写入端形成完整闭环。

**输出文件**: `PDF-Ve/Features/Document/DocumentViewModel.swift`（更新）

**实现要求**:

在 `DocumentViewModel.open(url:)` 方法中，文档加载成功后读取阅读状态并应用到 ReaderViewModel：

```swift
// 在 open(url:) 方法中
func open(url: URL) async {
    state = .loading
    do {
        let doc = try await fileService.openDocument(at: url)
        state = .loaded(doc, url)
        recentDocuments = fileService.recentDocuments()
        
        // T-02-04b: 读取并应用阅读位置
        if let readingState = fileService.readingState(for: url) {
            // 通知 ReaderViewModel 恢复位置
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
```

在 `MainWindowView` 中监听通知并应用：

```swift
.onReceive(NotificationCenter.default.publisher(for: .restoreReadingState)) { notification in
    if let page = notification.userInfo?["page"] as? Int {
        readerVM.goToPage(page)
    }
    if let zoom = notification.userInfo?["zoom"] as? Double {
        readerVM.setZoom(zoom)
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 首次打开文档时从数据库读取上次阅读位置
- [ ] **交互验证**: 文档加载完成后自动跳转到上次阅读的页码
- [ ] **交互验证**: 文档加载完成后自动恢复上次的缩放级别
- [ ] **数据流转验证**: `readingState(for:)` 返回 nil 时不执行恢复操作

**依赖**: T-02-04

---

### T-02-05: 拖拽打开 + 文件关联注册

**任务概述**: 配置 Info.plist 注册 PDF 文件关联，支持 Dock 图标拖入打开（AC-001-02, AC-001-03）。

**输出文件**:
- `PDF-Ve/App/Info.plist`（创建或更新）
- `PDF-Ve/App/AppDelegate.swift`（更新）

**实现要求**:

```xml
<!-- Info.plist 添加 PDF 文件类型关联 -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>PDF Document</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.adobe.pdf</string>
        </array>
        <key>NSDocumentClass</key>
        <string>$(PRODUCT_MODULE_NAME).PDFDocument</string>
    </dict>
</array>
```

```swift
// AppDelegate.swift 添加处理文件打开
// 通过 NSWorkspace / application(_:open:) 处理拖拽到 Dock 图标
extension AppDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in
            // 通知 DocumentViewModel 打开文件
            NotificationCenter.default.post(
                name: .openPDFURL,
                object: url
            )
        }
    }
}

extension Notification.Name {
    static let openPDFURL = Notification.Name("openPDFURL")
}
```

**验收标准**:
- [ ] 双击 PDF 文件可用 PDF-Ve 打开（系统设置为默认后）
- [ ] 拖拽 PDF 到 Dock 图标可打开

**依赖**: T-02-04

---

## 验收清单

- [ ] Cmd+O 打开文件选择对话框，选择 PDF 后正常显示
- [ ] 拖拽 PDF 文件到主窗口可打开
- [ ] 最近文件列表正确显示（最多20条，含文件名/路径/时间）
- [ ] 点击最近文件条目正常打开；文件不存在时提示并移除
- [ ] 关闭窗口时阅读状态保存（Rule-002，T-02-01 写入端）
- [ ] 打开文档时阅读位置恢复（Rule-002，T-02-04b 读取端）

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| API-001 openDocument | T-02-01 | ✅ |
| API-002 closeDocument | T-02-01 | ✅ |
| API-002b 读取阅读位置 | T-02-04b | ✅ |
| API-003 recentDocuments | T-02-01 | ✅ |
| API-004 openRecentDocument | T-02-01 | ✅ |
| STATE-001 文档打开状态机 | T-02-02 | ✅ |
| BOUND-001 文件打开边界 | T-02-01 | ✅ |
| BOUND-002 最近文件数量边界 | T-02-01（调 Repository） | ✅ |
| BOUND-003 路径失效边界 | T-02-01 | ✅ |
| AC-001-01~05 | T-02-01, T-02-04, T-02-05 | ✅ |
| AC-015-01~05 | T-02-02, T-02-03 | ✅ |
