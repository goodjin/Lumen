# 分层架构设计

## 文档信息

- **项目名称**: PDF-Ve
- **版本**: v1.0
- **对应PRD**: docs/v1/01-prd.md
- **更新日期**: 2026-04-01

---

## 1. 层次划分

| 层次 | 名称 | 职责 | 对应PRD功能 |
|-----|------|------|------------|
| L5 | 视图层（View） | 用户界面渲染、事件捕获、手势处理 | 全部 FR |
| L4 | ViewModel 层 | 状态管理、UI 逻辑、视图数据转换 | 全部 FR |
| L3 | 业务逻辑层（Service） | 核心业务规则、流程编排 | Rule-001~004 |
| L2 | 数据访问层（Repository） | 数据读写抽象、缓存策略 | Entity-001~003 |
| L1 | 基础设施层 | PDFKit、SwiftData、FileManager | 底层能力 |

---

## 2. 各层职责详情

### L5: 视图层

**技术**: SwiftUI View + NSViewRepresentable（PDFView 封装）

| 视图组件 | 职责 | 对应功能 |
|---------|------|---------|
| `MainWindowView` | 主窗口布局，组合侧栏+阅读区+工具栏 | 全局容器 |
| `ToolbarView` | 工具栏：打开、翻页、页码、缩放、标注工具切换 | FR-001~003, FR-006~010 |
| `PDFReaderView` | 包装 PDFKit PDFView，处理手势 | FR-002, FR-003, FR-014 |
| `AnnotationOverlayView` | 覆盖在 PDFView 上的标注渲染层 | FR-006~010 |
| `SearchBarView` | 搜索输入框、结果导航 | FR-005 |
| `SidebarView` | 侧栏容器，含4个Tab | FR-004, FR-011~013 |
| `OutlineView` | 目录树 | FR-004 |
| `AnnotationListView` | 标注列表 | FR-011 |
| `BookmarkListView` | 书签列表 | FR-012 |
| `ThumbnailGridView` | 页面缩略图网格 | FR-013 |
| `RecentFilesView` | 最近文件列表（启动页） | FR-015 |

**规则**：
- 视图层不包含业务逻辑，只做展示和事件分发
- 视图通过 `@StateObject` / `@ObservedObject` 绑定 ViewModel

### L4: ViewModel 层

**技术**: `@Observable` (iOS 17+/macOS 14+) 或 `ObservableObject`

| ViewModel | 职责 | 对应功能 |
|----------|------|---------|
| `DocumentViewModel` | 文档打开状态、最近文件列表、文档元数据 | FR-001, FR-015, Rule-002~004 |
| `ReaderViewModel` | 当前页码、缩放级别、滚动位置、全屏状态 | FR-002, FR-003, FR-014 |
| `AnnotationViewModel` | 标注工具选择、当前标注集合、标注 CRUD | FR-006~010, FR-011, Flow-001 |
| `SearchViewModel` | 搜索关键词、搜索结果、当前匹配索引 | FR-005 |
| `SidebarViewModel` | 侧栏显示状态、当前 Tab 选择 | FR-004, FR-011~013 |
| `BookmarkViewModel` | 书签集合、书签 CRUD | FR-012 |

### L3: 业务逻辑层

**技术**: 纯 Swift 类/结构体，无 UI 依赖

| Service | 职责 | 对应功能/规则 |
|---------|------|-------------|
| `FileService` | 文件打开、路径校验、最近文件管理 | FR-001, FR-015, Rule-002~004 |
| `AnnotationService` | 标注创建、修改、删除、立即持久化触发 | FR-006~010, Rule-001, Flow-001~002 |
| `BookmarkService` | 书签增删改查 | FR-012 |
| `SearchService` | 调用 PDFKit 搜索、结果封装 | FR-005 |
| `ExportService` | 标注数据导出为文本 | FR-016 |

**关键业务规则实现**：
- `Rule-001`：`AnnotationService` 所有写操作只写 Repository，不调用 `PDFAnnotation` 写入 API
- `Rule-002`：`FileService.closeDocument()` 触发 `DocumentRepository.saveReadingState()`
- `Rule-003`：`FileService.openRecentFile()` 先调用 `FileManager.fileExists()`，失败则调用 `DocumentRepository.removeRecentFile()`
- `Rule-004`：`FileService.recordRecentFile()` 写入后检查总数，超过 20 条时删除最旧记录

### L2: 数据访问层

**技术**: Repository Pattern，屏蔽 SwiftData/CoreData 细节

| Repository | 职责 | 对应实体 |
|-----------|------|---------|
| `DocumentRepository` | Document 记录的增删改查 | Entity-001 |
| `AnnotationRepository` | Annotation 记录的增删改查，按文档路径索引 | Entity-002 |
| `BookmarkRepository` | Bookmark 记录的增删改查，按文档路径索引 | Entity-003 |

### L1: 基础设施层

| 组件 | 提供能力 | 使用方 |
|-----|---------|-------|
| `PDFKit.PDFDocument` | PDF 解析、页面数量、目录读取 | MOD-02, MOD-03 |
| `PDFKit.PDFView` | PDF 页面渲染、文本选择 | MOD-02 |
| `PDFKit.PDFDocument.findString` | 全文搜索 | MOD-04 |
| `SwiftData.ModelContainer` | 数据持久化 | L2 全部 Repository |
| `Foundation.FileManager` | 文件存在检查、路径操作 | FileService |

---

## 3. 层间依赖规则

- **上层依赖下层**，禁止下层依赖上层
- **L5（视图）→ L4（ViewModel）**：通过 `@Binding` / `@ObservedObject` 绑定
- **L4（ViewModel）→ L3（Service）**：直接调用 Service 方法
- **L3（Service）→ L2（Repository）**：通过 Repository 协议调用
- **L2（Repository）→ L1（基础设施）**：直接使用 SwiftData / FileManager

---

## 4. 功能-层次映射

| PRD 功能 | L5 视图 | L4 ViewModel | L3 Service | L2 Repository |
|---------|---------|-------------|-----------|--------------|
| FR-001 | MainWindowView, ToolbarView | DocumentViewModel | FileService | DocumentRepository |
| FR-002 | PDFReaderView | ReaderViewModel | - | - |
| FR-003 | PDFReaderView, ToolbarView | ReaderViewModel | - | - |
| FR-004 | SidebarView, OutlineView | SidebarViewModel | - | - |
| FR-005 | SearchBarView | SearchViewModel | SearchService | - |
| FR-006~010 | AnnotationOverlayView | AnnotationViewModel | AnnotationService | AnnotationRepository |
| FR-011 | AnnotationListView | AnnotationViewModel | - | AnnotationRepository |
| FR-012 | BookmarkListView | BookmarkViewModel | BookmarkService | BookmarkRepository |
| FR-013 | ThumbnailGridView | SidebarViewModel | - | - |
| FR-014 | PDFReaderView | ReaderViewModel | - | - |
| FR-015 | RecentFilesView | DocumentViewModel | FileService | DocumentRepository |
| FR-016 | Menu | AnnotationViewModel | ExportService | AnnotationRepository |
