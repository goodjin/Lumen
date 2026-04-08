# P-08: MOD-07 侧栏模块

## 文档信息

- **计划编号**: P-08
- **批次**: 第4批
- **对应架构**: docs/v1/02-architecture/03-mod07-sidebar.md
- **优先级**: P1
- **前置依赖**: P-04, P-06, P-07

---

## 模块职责

完善侧栏：添加「标注」「书签」「页面」Tab，实现标注列表筛选跳转、书签增删改查、页面缩略图网格。对应 PRD: FR-011, FR-012, FR-013。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-08-01 | BookmarkService | 1 | ~80 | P-07 |
| T-08-02 | SidebarViewModel | 1 | ~100 | T-08-01, P-06 |
| T-08-03a | AnnotationListView 标注列表渲染 | 1 | ~80 | T-08-02 |
| T-08-03b | AnnotationListView 标注点击跳转（VIEW-API-003） | 1 | ~40 | T-08-03a |
| T-08-04 | BookmarkListView | 1 | ~100 | T-08-02 |
| T-08-05a | ThumbnailGridView 缩略图网格渲染 + ThumbnailProvider | 2 | ~100 | P-03 |
| T-08-05b | ThumbnailGridView 缩略图点击跳转（VIEW-API-005） | 1 | ~30 | T-08-05a |
| T-08-06 | 整合 SidebarView + Cmd+B 快捷键 | 1 | ~60 | T-08-03b, T-08-04, T-08-05b |
| T-08-07 | 页面跳转级联更新验证（API-010 级联影响） | 1 | ~50 | T-08-06 |

---

## 详细任务定义

### T-08-01: BookmarkService

**输出文件**: `PDF-Ve/Features/Sidebar/BookmarkService.swift`

**实现要求**:

```swift
import Foundation

@MainActor
class BookmarkService {
    private let repository: BookmarkRepository

    init(repository: BookmarkRepository) {
        self.repository = repository
    }

    // API-063: 切换书签（同一页已有则删除，无则创建）
    func toggleBookmark(at pageNumber: Int, in documentPath: String) {
        if let existing = repository.find(documentPath: documentPath, pageNumber: pageNumber) {
            try? repository.delete(id: existing.id)
        } else {
            let bookmark = BookmarkRecord(documentPath: documentPath, pageNumber: pageNumber)
            try? repository.save(bookmark)
        }
    }

    // API-064: 重命名书签（空字符串时忽略）
    func renameBookmark(id: UUID, name: String, in documentPath: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let bookmark = repository.find(documentPath: documentPath, pageNumber: 0) else {
            // 通过 id 查找
            return
        }
        bookmark.name = trimmed
        try? repository.save(bookmark)
    }

    // API-066: 删除书签
    func deleteBookmark(id: UUID) {
        try? repository.delete(id: id)
    }

    func bookmarks(for documentPath: String) -> [BookmarkRecord] {
        repository.fetchAll(for: documentPath)
    }

    func isBookmarked(pageNumber: Int, documentPath: String) -> Bool {
        repository.find(documentPath: documentPath, pageNumber: pageNumber) != nil
    }
}
```

**验收标准**:
- [ ] 同一页重复调用 `toggleBookmark` 实现删除（AC-012-01）
- [ ] `renameBookmark` 空字符串输入不执行（AC-012-04 边界）
- [ ] 书签默认名称为「第N页」（DATA-003 初始化逻辑）

---

### T-08-02: SidebarViewModel

**输出文件**: `PDF-Ve/Features/Sidebar/SidebarViewModel.swift`

**实现要求**:

```swift
import PDFKit
import SwiftUI

@MainActor
@Observable
class SidebarViewModel {
    private let bookmarkService: BookmarkService
    var readerVM: ReaderViewModel
    var annotationVM: AnnotationViewModel

    var bookmarks: [BookmarkRecord] = []
    var annotationFilter: AnnotationType? = nil  // nil = 全部

    var documentPath: String = ""

    init(bookmarkService: BookmarkService,
         readerVM: ReaderViewModel,
         annotationVM: AnnotationViewModel) {
        self.bookmarkService = bookmarkService
        self.readerVM = readerVM
        self.annotationVM = annotationVM
    }

    func loadForDocument(_ path: String) {
        documentPath = path
        refreshBookmarks()
    }

    func refreshBookmarks() {
        bookmarks = bookmarkService.bookmarks(for: documentPath)
    }

    // API-061: 筛选标注
    func filteredAnnotations() -> [AnnotationRecord] {
        guard let filter = annotationFilter else {
            return annotationVM.annotations
        }
        return annotationVM.annotations.filter { $0.type == filter }
    }

    // API-062: 点击标注跳转
    func selectAnnotation(_ annotation: AnnotationRecord) {
        readerVM.goToPage(annotation.pageNumber)
    }

    // API-065: 点击书签跳转
    func selectBookmark(_ bookmark: BookmarkRecord) {
        readerVM.goToPage(bookmark.pageNumber)
    }

    // API-063: 切换书签
    func toggleBookmark() {
        bookmarkService.toggleBookmark(at: readerVM.currentPage, in: documentPath)
        refreshBookmarks()
    }

    // API-064: 重命名
    func renameBookmark(id: UUID, name: String) {
        // 找到书签并更新名称
        if let bookmark = bookmarks.first(where: { $0.id == id }) {
            bookmark.name = name.trimmingCharacters(in: .whitespaces).isEmpty
                ? bookmark.name : name
            try? bookmarkService.repository.save(bookmark)
            refreshBookmarks()
        }
    }

    // API-066: 删除书签
    func deleteBookmark(id: UUID) {
        bookmarkService.deleteBookmark(id: id)
        refreshBookmarks()
    }

    var isCurrentPageBookmarked: Bool {
        bookmarkService.isBookmarked(pageNumber: readerVM.currentPage,
                                     documentPath: documentPath)
    }
}
```

**验收标准**:
- [ ] `filteredAnnotations()` nil 返回全部，非 nil 按类型过滤（AC-011-05）
- [ ] `toggleBookmark()` 调用后 `bookmarks` 列表实时更新

---

### T-08-03a: AnnotationListView 标注列表渲染

**输出文件**: `PDF-Ve/Features/Sidebar/AnnotationListView.swift`

**实现要求**:

```swift
import SwiftUI

struct AnnotationListView: View {
    @Bindable var sidebarVM: SidebarViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 类型筛选器（AC-011-05）
            filterBar

            Divider()

            let items = sidebarVM.filteredAnnotations()
            if items.isEmpty {
                // 空状态（AC-011-06）
                ContentUnavailableView(
                    sidebarVM.annotationFilter == nil ? "暂无标注" : "该类型暂无标注",
                    systemImage: "highlighter"
                )
            } else {
                List(items, id: \.id) { annotation in
                    AnnotationRow(annotation: annotation)
                        // T-08-03b: 点击跳转在独立任务中实现
                        .onTapGesture {
                            sidebarVM.selectAnnotation(annotation)
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(title: "全部", isSelected: sidebarVM.annotationFilter == nil) {
                    sidebarVM.annotationFilter = nil
                }
                ForEach(AnnotationType.allCases, id: \.self) { type in
                    FilterChip(title: type.displayName,
                               isSelected: sidebarVM.annotationFilter == type) {
                        sidebarVM.annotationFilter =
                            sidebarVM.annotationFilter == type ? nil : type
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

struct AnnotationRow: View {
    let annotation: AnnotationRecord

    var body: some View {
        HStack(spacing: 8) {
            // 类型颜色指示条
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: annotation.colorHex) ?? .yellow)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(annotation.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("第\(annotation.pageNumber)页")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let content = annotation.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension AnnotationType {
    var displayName: String {
        switch self {
        case .highlight:     return "高亮"
        case .underline:     return "下划线"
        case .strikethrough: return "删除线"
        case .note:          return "注释"
        case .drawing:       return "绘制"
        }
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 列表显示标注类型、内容摘要、页码，按页码升序排列（AC-011-01 ~ AC-011-03）
- [ ] **数据展示验证**: 无标注时显示「暂无标注」空状态（AC-011-06）
- [ ] **数据展示验证**: 筛选后无结果时显示「该类型暂无标注」
- [ ] **布局验证**: 侧栏宽度 240pt，列表撑满可用高度（UI-Layout-003）
- [ ] **交互验证**: 筛选 Chip 可切换类型，选中状态视觉反馈正确（AC-011-05）

**依赖**: T-08-02

---

### T-08-03b: AnnotationListView 标注点击跳转（VIEW-API-003）

**任务概述**: 实现标注列表项点击跳转功能。这是 VIEW-API-003 的独立实现任务，验证点击 → 跳转 → 目标位置正确加载的完整链路。

**输出文件**: `PDF-Ve/Features/Sidebar/AnnotationListView.swift`（更新点击处理）

**实现要求**:

已在 T-08-03a 中预留 `.onTapGesture`，本任务验证并完善交互逻辑：

```swift
List(items, id: \.id) { annotation in
    AnnotationRow(annotation: annotation)
        .onTapGesture {
            // VIEW-API-003: 标注列表项点击跳转
            // 调用链: AnnotationListView.onTapGesture
            //   → SidebarViewModel.selectAnnotation(annotation)
            //     → ReaderViewModel.goToPage(annotation.pageNumber)
            sidebarVM.selectAnnotation(annotation)
        }
}
```

**验收标准**:
- [ ] **交互验证**: 点击标注条目触发 `onTapGesture` 事件
- [ ] **数据流转验证**: `sidebarVM.selectAnnotation()` 被正确调用，参数传递正确
- [ ] **级联影响验证**: `ReaderViewModel.goToPage()` 被正确调用
- [ ] **端到端验证**: 点击标注后主视图跳转到对应页面，标注位置正确显示（AC-011-04）

**依赖**: T-08-03a

---

### T-08-04: BookmarkListView

**输出文件**: `PDF-Ve/Features/Sidebar/BookmarkListView.swift`

**实现要求**:

```swift
import SwiftUI

struct BookmarkListView: View {
    @Bindable var sidebarVM: SidebarViewModel
    @State private var editingBookmarkId: UUID? = nil
    @State private var editingName: String = ""

    var body: some View {
        Group {
            if sidebarVM.bookmarks.isEmpty {
                ContentUnavailableView("暂无书签",
                    systemImage: "bookmark",
                    description: Text("按 Cmd+B 在当前页添加书签"))
            } else {
                List {
                    ForEach(sidebarVM.bookmarks, id: \.id) { bookmark in
                        bookmarkRow(bookmark)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private func bookmarkRow(_ bookmark: BookmarkRecord) -> some View {
        HStack {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.orange)

            if editingBookmarkId == bookmark.id {
                // 重命名输入框（AC-012-04）
                TextField("书签名称", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sidebarVM.renameBookmark(id: bookmark.id, name: editingName)
                        editingBookmarkId = nil
                    }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.name)
                        .lineLimit(1)
                    Text("第\(bookmark.pageNumber)页")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onTapGesture {
                    // 点击跳转（AC-012-05）
                    sidebarVM.selectBookmark(bookmark)
                }
                .onTapGesture(count: 2) {
                    // 双击重命名（AC-012-04）
                    editingBookmarkId = bookmark.id
                    editingName = bookmark.name
                }
            }

            Spacer()
        }
        .contextMenu {
            Button("重命名") {
                editingBookmarkId = bookmark.id
                editingName = bookmark.name
            }
            Divider()
            Button("删除书签", role: .destructive) {
                sidebarVM.deleteBookmark(id: bookmark.id)
            }
        }
    }
}
```

**验收标准**:
- [ ] 书签列表显示名称和页码（AC-012-02, AC-012-03）
- [ ] 双击可重命名，回车确认（AC-012-04）
- [ ] 点击跳转到对应页面（AC-012-05）
- [ ] 右键菜单支持重命名和删除（AC-012-07）
- [ ] 无书签时显示提示（含 Cmd+B 提示）

---

### T-08-05a: ThumbnailGridView 缩略图网格渲染 + ThumbnailProvider

**输出文件**:
- `PDF-Ve/Features/Sidebar/ThumbnailGridView.swift`
- `PDF-Ve/Features/Sidebar/ThumbnailProvider.swift`

**实现要求**:

```swift
// ThumbnailProvider.swift
import PDFKit
import AppKit

actor ThumbnailProvider {
    private var cache: [Int: NSImage] = [:]  // pageIndex → NSImage
    private let thumbnailSize = CGSize(width: 120, height: 160)

    // API-067: 异步生成缩略图（AC-013-05 按需加载）
    func thumbnail(for page: PDFPage, pageIndex: Int) async -> NSImage {
        if let cached = cache[pageIndex] { return cached }
        let image = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        cache[pageIndex] = image
        return image
    }

    func clearCache() {
        cache.removeAll()
    }
}

// ThumbnailGridView.swift
import SwiftUI
import PDFKit

struct ThumbnailGridView: View {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel
    private let provider = ThumbnailProvider()

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 130), spacing: 8)
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        ThumbnailCell(
                            document: document,
                            pageIndex: index,
                            isCurrentPage: readerVM.currentPage == index + 1,
                            provider: provider
                        )
                        // T-08-05b: 点击跳转在独立任务中实现
                        .onTapGesture {
                            readerVM.goToPage(index + 1)
                        }
                        .id(index)
                    }
                }
                .padding(8)
            }
            // 当前页高亮并滚动到视图内（AC-013-03）
            .onChange(of: readerVM.currentPage) { _, newPage in
                withAnimation {
                    proxy.scrollTo(newPage - 1, anchor: .center)
                }
            }
        }
    }
}

struct ThumbnailCell: View {
    let document: PDFDocument
    let pageIndex: Int
    let isCurrentPage: Bool
    let provider: ThumbnailProvider

    @State private var image: NSImage? = nil

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // 加载占位（AC-013-05）
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .overlay(
                // 当前页蓝色边框（AC-013-03）
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isCurrentPage ? Color.accentColor : Color.clear,
                            lineWidth: 2)
            )
            .cornerRadius(3)

            Text("\(pageIndex + 1)")
                .font(.caption2)
                .foregroundStyle(isCurrentPage ? .accentColor : .secondary)
        }
        .task {
            // 进入视口时才加载（LazyVGrid 保证）（AC-013-05）
            guard let page = document.page(at: pageIndex) else { return }
            image = await provider.thumbnail(for: page, pageIndex: pageIndex)
        }
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 缩略图网格显示所有页面（AC-013-01）
- [ ] **数据展示验证**: 缩略图显示页码（AC-013-02）
- [ ] **数据展示验证**: 当前页高亮蓝色边框（AC-013-03）
- [ ] **数据展示验证**: 缩略图加载失败显示灰色占位
- [ ] **布局验证**: 缩略图宽度 90pt~130pt 自适应，网格间距 8pt/12pt（UI-Layout-004）
- [ ] **布局验证**: 侧栏宽度 240pt，缩略图网格撑满可用高度
- [ ] **交互验证**: 视口外页面不立即加载（AC-013-05）
- [ ] **交互验证**: 当前页变更时自动滚动到视图内

**依赖**: P-03

---

### T-08-05b: ThumbnailGridView 缩略图点击跳转（VIEW-API-005）

**任务概述**: 实现缩略图点击跳转功能。这是 VIEW-API-005 的独立实现任务，验证点击 → 跳转 → 目标位置正确加载的完整链路。

**输出文件**: `PDF-Ve/Features/Sidebar/ThumbnailGridView.swift`（更新点击处理）

**实现要求**:

已在 T-08-05a 中预留 `.onTapGesture`，本任务验证并完善交互逻辑：

```swift
LazyVGrid(columns: columns, spacing: 12) {
    ForEach(0..<document.pageCount, id: \.self) { index in
        ThumbnailCell(
            document: document,
            pageIndex: index,
            isCurrentPage: readerVM.currentPage == index + 1,
            provider: provider
        )
        // VIEW-API-005: 缩略图点击跳转
        // 调用链: ThumbnailCell.onTapGesture
        //   → ReaderViewModel.goToPage(pageNumber)
        .onTapGesture {
            readerVM.goToPage(index + 1)
        }
        .id(index)
    }
}
```

**验收标准**:
- [ ] **交互验证**: 点击缩略图触发 `onTapGesture` 事件
- [ ] **数据流转验证**: `readerVM.goToPage()` 被正确调用，页码参数正确（index + 1）
- [ ] **级联影响验证**: 页面跳转后 `readerVM.currentPage` 更新，缩略图高亮边框同步更新
- [ ] **端到端验证**: 点击缩略图后主视图跳转到对应页面（AC-013-04）

**依赖**: T-08-05a

---

### T-08-06: 整合 SidebarView + Cmd+B 快捷键

更新 `SidebarView`（P-04 T-04-03 已创建骨架），添加三个新 Tab，并在 `MainWindowView` 集成 Cmd+B：

```swift
// SidebarView.swift（更新）
import SwiftUI

struct SidebarView: View {
    var outlineVM: OutlineViewModel
    var sidebarVM: SidebarViewModel
    var readerVM: ReaderViewModel
    var document: PDFDocument

    var body: some View {
        TabView {
            OutlineView(outlineVM: outlineVM, readerVM: readerVM)
                .tabItem { Label("目录", systemImage: "list.bullet.indent") }

            // 新增 Tab（P-08）
            AnnotationListView(sidebarVM: sidebarVM)
                .tabItem { Label("标注", systemImage: "highlighter") }

            BookmarkListView(sidebarVM: sidebarVM)
                .tabItem { Label("书签", systemImage: "bookmark") }

            ThumbnailGridView(document: document, readerVM: readerVM)
                .tabItem { Label("页面", systemImage: "square.grid.2x2") }
        }
        .frame(minWidth: 200, idealWidth: 240)
    }
}

// MainWindowView 中添加 Cmd+B 快捷键：
// 在 .loaded 状态的 VStack 上添加：
.keyboardShortcut("b", modifiers: .command) {
    sidebarVM.toggleBookmark()
}
// 工具栏书签按钮（可选，显示当前页是否已书签）：
Button(action: { sidebarVM.toggleBookmark() }) {
    Image(systemName: sidebarVM.isCurrentPageBookmarked
          ? "bookmark.fill" : "bookmark")
}
.help(sidebarVM.isCurrentPageBookmarked ? "移除书签" : "添加书签")
.keyboardShortcut("b", modifiers: .command)
```

并在 `.loaded` 状态触发加载：
```swift
case .loaded(let doc, let url):
    // 加载该文档的标注和书签
    let _ = { sidebarVM.loadForDocument(url.path) }()
    // ...
```

**验收标准**:
- [ ] **数据展示验证**: 侧栏显示「目录」「标注」「书签」「页面」四个 Tab（AC-011-01, AC-012-01, AC-013-01）
- [ ] **布局验证**: 侧栏宽度 240pt，TabView 撑满可用高度（UI-Layout-003）
- [ ] **交互验证**: Cmd+B 切换当前页书签状态，工具栏书签图标状态同步更新（AC-012-01, AC-012-02）

**依赖**: T-08-03b, T-08-04, T-08-05b

---

### T-08-07: 页面跳转级联更新验证（API-010 级联影响）

**任务概述**: 验证 API-010 `goToPage` 的级联影响是否完整实现。根据架构文档 API-010 的后置影响定义，页面跳转会触发多个模块的状态更新，本任务验证所有级联更新是否正确。

**输出文件**: 验证任务，无需新文件，更新相关视图确保监听正确

**实现要求**:

验证以下级联影响（来自架构文档 API-010）：

```swift
// 1. ThumbnailGridView 当前页高亮边框
// ReaderViewModel.currentPage 变更 → ThumbnailCell.isCurrentPage 更新
.onChange(of: readerVM.currentPage) { _, newPage in
    withAnimation {
        proxy.scrollTo(newPage - 1, anchor: .center)
    }
}

// 2. BookmarkListView 当前页书签指示器
// 已在 T-08-06 中通过 sidebarVM.isCurrentPageBookmarked 实现

// 3. ToolbarView 页码显示
// ReaderToolbarView 通过 @Bindable var readerVM 自动同步

// 4. 阅读位置保存（Rule-002）
// MainWindowView.onDisappear 中调用 docVM.close()

// 5. 搜索高亮清除（如搜索模块已实现）
// 页面变更时应清除当前搜索高亮

// 6. AnnotationOverlayView 标注高亮
// 跳转后应高亮显示目标页的标注
```

**验收标准**:
- [ ] **级联影响验证**: 页面跳转后缩略图网格当前页蓝色边框同步更新
- [ ] **级联影响验证**: 页面跳转后书签列表当前页指示器同步更新
- [ ] **级联影响验证**: 页面跳转后工具栏页码显示同步更新
- [ ] **级联影响验证**: 页面跳转后阅读位置自动保存（Rule-002）
- [ ] **级联影响验证**: 页面跳转后搜索高亮清除（如适用）
- [ ] **级联影响验证**: 页面跳转后目标页标注正确高亮显示

**依赖**: T-08-06

---

## 验收清单

- [ ] 标注列表显示所有标注，支持类型筛选（AC-011-01 ~ AC-011-06）
- [ ] 点击标注/书签/缩略图均可跳转对应页（AC-011-04, AC-012-05, AC-013-04）
- [ ] Cmd+B 添加/删除书签（AC-012-01）
- [ ] 书签支持双击重命名（AC-012-04）
- [ ] 缩略图网格按需加载（AC-013-05）
- [ ] 当前页缩略图有蓝色高亮边框（AC-013-03）

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| API-060 annotations | T-08-02 SidebarViewModel | ✅ |
| API-061 filterAnnotations | T-08-03a AnnotationListView | ✅ |
| API-062 selectAnnotation | T-08-02 SidebarViewModel, T-08-03b | ✅ |
| API-063 toggleBookmark | T-08-01 BookmarkService | ✅ |
| API-064 renameBookmark | T-08-01 BookmarkService | ✅ |
| API-065 selectBookmark | T-08-02 SidebarViewModel | ✅ |
| API-066 deleteBookmark | T-08-01 BookmarkService | ✅ |
| API-067 thumbnail | T-08-05a ThumbnailProvider | ✅ |
| VIEW-API-003 标注点击跳转 | T-08-03b | ✅ |
| VIEW-API-005 缩略图点击跳转 | T-08-05b | ✅ |
| API-010 级联影响 | T-08-07 | ✅ |
| BOUND-040 标注列表边界 | T-08-03a | ✅ |
| BOUND-041 书签边界 | T-08-01, T-08-04 | ✅ |
| BOUND-042 缩略图边界 | T-08-05a | ✅ |
| UI-Layout-003 侧栏布局 | T-08-03a, T-08-06 | ✅ |
| UI-Layout-004 缩略图网格布局 | T-08-05a | ✅ |
| SidebarTab 枚举 | T-08-06 | ✅ |
| FR-011 标注列表 | T-08-02, T-08-03a, T-08-03b | ✅ |
| FR-012 书签 | T-08-01, T-08-04 | ✅ |
| FR-013 缩略图 | T-08-05a, T-08-05b | ✅ |
| AC-011-01~06 | T-08-02, T-08-03a, T-08-03b | ✅ |
| AC-012-01~07 | T-08-01, T-08-04, T-08-06 | ✅ |
| AC-013-01~05 | T-08-05a, T-08-05b, T-08-06 | ✅ |
