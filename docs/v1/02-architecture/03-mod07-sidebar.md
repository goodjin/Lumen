# MOD-07: 侧栏模块

## 文档信息

- **模块编号**: MOD-07
- **版本**: v1.0
- **更新日期**: 2026-04-01
- **对应PRD**: FR-011, FR-012, FR-013
- **对应用户故事**: US-011, US-012, US-013

---

## 系统定位

```
┌─────────────────────────────────────────────────────┐
│  L5: SidebarView                                    │
│       ├── AnnotationListView  (FR-011)               │
│       ├── BookmarkListView    (FR-012)               │
│       └── ThumbnailGridView   (FR-013)               │
│  L4: SidebarViewModel / BookmarkViewModel           │
└──────────────────────┬──────────────────────────────┘
                       │ ▼ 调用
┌──────────────────────▼──────────────────────────────┐
│         ★ MOD-07: 侧栏模块 ★                        │
│         BookmarkService                             │
└──────────────────────┬──────────────────────────────┘
                       │ ▼ 依赖
┌──────────────────────▼──────────────────────────────┐
│  MOD-06 AnnotationRepository（读取标注列表）          │
│  MOD-06 BookmarkRepository（书签 CRUD）              │
│  MOD-02 ReaderViewModel（页面跳转）                  │
│  PDFKit.PDFPage（缩略图生成）                        │
└─────────────────────────────────────────────────────┘
```

### 核心职责

- **标注列表**（FR-011）：展示当前文档所有标注，支持筛选和点击跳转
- **书签管理**（FR-012）：书签增删改查，支持重命名
- **页面缩略图**（FR-013）：展示所有页面缩略图网格，按需渲染，点击跳转
- 侧栏整体显示/隐藏（Cmd+T）

---

## 对应 PRD

| PRD 编号 | 内容 |
|---------|------|
| FR-011 | 标注列表侧栏 |
| FR-012 | 书签 |
| FR-013 | 页面缩略图 |
| US-011 | 查看标注列表 |
| US-012 | 书签管理 |
| US-013 | 页面缩略图 |
| AC-011-01~06 | 标注列表验收 |
| AC-012-01~07 | 书签验收 |
| AC-013-01~05 | 缩略图验收 |

---

## 接口定义

### 标注列表

#### API-060: 获取标注列表

**对应 PRD**: AC-011-01 ~ AC-011-03

```swift
// AnnotationViewModel（读取）
var annotations: [AnnotationRecord]
// 已从 MOD-06 加载，按 pageNumber 升序
// SidebarViewModel 监听此集合，驱动 AnnotationListView 更新
```

#### API-061: 按类型筛选标注

**对应 PRD**: AC-011-05

```swift
// SidebarViewModel
func filterAnnotations(by type: AnnotationType?) -> [AnnotationRecord]
// type == nil → 返回全部
// type == .highlight → 只返回高亮
```

#### API-062: 点击标注跳转

**对应 PRD**: AC-011-04

```swift
// SidebarViewModel
func selectAnnotation(_ annotation: AnnotationRecord)
// 1. 调用 ReaderViewModel.goToPage(annotation.pageNumber)
// 2. 通知 AnnotationOverlayView 高亮该标注（短暂闪烁效果）
```

---

### 书签管理

#### API-063: 添加/删除书签（切换）

**对应 PRD**: AC-012-01, Cmd+B

```swift
// BookmarkService
func toggleBookmark(at pageNumber: Int, in documentPath: String)
// 若当前页已有书签 → 删除
// 若当前页无书签 → 创建（默认名称「第X页」）
```

#### API-064: 重命名书签

**对应 PRD**: AC-012-04

```swift
// BookmarkService
func renameBookmark(id: UUID, name: String)
// name 不能为空，空时保持原名不变
```

#### API-065: 点击书签跳转

**对应 PRD**: AC-012-05

```swift
// SidebarViewModel
func selectBookmark(_ bookmark: BookmarkRecord)
// 调用 ReaderViewModel.goToPage(bookmark.pageNumber)
```

#### API-066: 删除书签

**对应 PRD**: AC-012-07

```swift
// BookmarkService
func deleteBookmark(id: UUID)
```

---

### 页面缩略图

#### API-067: 生成页面缩略图

**对应 PRD**: AC-013-01 ~ AC-013-05

```swift
// ThumbnailProvider（独立组件）
func thumbnail(for page: PDFPage, size: CGSize) async -> NSImage
// 使用 PDFPage.thumbnail(of:for:) API
// async：按需生成，不阻塞主线程（AC-013-05 按需加载）
```

**缩略图规格**：
- 默认尺寸：宽 120pt，高按比例计算
- 使用 `LazyVGrid` + `task {}` 实现视口内按需加载

---

## 数据结构

### DATA-003: BookmarkRecord

**对应 PRD**: Entity-003

```swift
@Model
final class BookmarkRecord {
    var id: UUID                    // PK
    var documentPath: String        // FK，所属文档路径
    var pageNumber: Int             // 书签页码（1-indexed）
    var name: String                // 书签名称
    var createdAt: Date             // 创建时间

    init(documentPath: String, pageNumber: Int) {
        self.id = UUID()
        self.documentPath = documentPath
        self.pageNumber = pageNumber
        self.name = "第\(pageNumber)页"
        self.createdAt = Date()
    }
}
```

### SidebarTab 枚举

```swift
enum SidebarTab: String, CaseIterable, Identifiable {
    case outline     = "目录"
    case annotations = "标注"
    case bookmarks   = "书签"
    case thumbnails  = "页面"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .outline:     return "list.bullet.indent"
        case .annotations: return "highlighter"
        case .bookmarks:   return "bookmark"
        case .thumbnails:  return "square.grid.2x2"
        }
    }
}
```

---

## View 层交互接口

### VIEW-API-003: 标注列表项点击跳转

**对应PRD**: US-011, AC-011-04

**手势**: 单击 (Tap)
**触发源**: `AnnotationListView` 中的标注条目

**调用链**：
```
AnnotationListView.onTapGesture
  → SidebarViewModel.selectAnnotation(annotation)
    → ReaderViewModel.goToPage(annotation.pageNumber)
      → AnnotationOverlayView 高亮该标注
```

**后置影响**：
- 同 API-010 级联影响
- 额外：`AnnotationOverlayView` 高亮选中的标注（如有位置信息）

---

### VIEW-API-004: 书签列表项点击跳转

**对应PRD**: US-012, AC-012-05

**手势**: 单击 (Tap)
**触发源**: `BookmarkListView` 中的书签条目

**调用链**：
```
BookmarkListView.onTapGesture
  → SidebarViewModel.selectBookmark(bookmark)
    → ReaderViewModel.goToPage(bookmark.pageNumber)
```

**后置影响**：同 API-010 级联影响

---

### VIEW-API-005: 缩略图点击跳转

**对应PRD**: US-013, AC-013-04

**手势**: 单击 (Tap)
**触发源**: `ThumbnailGridView` 中的 `ThumbnailCell`

**调用链**：
```
ThumbnailCell.onTapGesture { readerVM.goToPage(index + 1) }
  → ReaderViewModel.goToPage(pageNumber)
```

**参数**：
| 参数 | 类型 | 说明 |
|-----|------|------|
| `index` | `Int` | 缩略图索引（0-based），实际页码 = index + 1 |

**后置影响**：同 API-010 级联影响

---

## UI 布局约束

### UI-Layout-003: 侧栏 (SidebarView)

**尺寸约束**：
| 属性 | 值 | 说明 |
|-----|-----|------|
| 宽度 | 240pt（展开时）/ 0pt（收起时） | 固定宽度，不可拖动调整 |
| 高度 | 撑满父容器减去工具栏高度 | 从工具栏下方到窗口底部 |

**边距**：
| 属性 | 值 |
|-----|-----|
| TabView 内边距 | 0pt（全填充） |
| 列表项内边距 | 标准 SwiftUI List 内边距 |

**响应式规则**：
- Cmd+T 切换显示/隐藏
- 全屏模式下自动隐藏（通过 `NSWindow.didEnterFullScreenNotification`）

### UI-Layout-004: 缩略图网格 (ThumbnailGridView)

**尺寸约束**：
| 属性 | 值 |
|-----|-----|
| 缩略图宽度 | 90pt ~ 130pt（自适应） |
| 缩略图高度 | 按比例计算（3:4） |
| 网格间距 | 8pt（水平）/ 12pt（垂直） |

**边距**：
- 整体内边距：8pt

---

## 边界条件

### BOUND-040: 标注列表边界

| 条件 | 处理 |
|-----|------|
| 文档无标注 | 显示「暂无标注」空状态视图（AC-011-06 异常） |
| 筛选后无结果 | 显示「该类型暂无标注」 |

### BOUND-041: 书签边界

| 条件 | 处理 |
|-----|------|
| 同一页重复添加书签（Cmd+B） | 删除已有书签（切换语义，AC-012-01） |
| 重命名时输入空字符串 | 忽略，保持原名 |
| 删除当前页的书签后再查看书签列表 | 列表实时更新，该书签消失 |

### BOUND-042: 缩略图边界

| 条件 | 处理 |
|-----|------|
| 视口外的缩略图 | 不生成（LazyVGrid 按需渲染，AC-013-05） |
| 缩略图生成失败 | 显示灰色占位图 |
| 当前页缩略图 | 高亮边框（蓝色 2pt，AC-013-03） |

---

## 实现文件

| 文件路径 | 职责 |
|---------|------|
| `Features/Sidebar/SidebarView.swift` | 侧栏容器（TabView） |
| `Features/Sidebar/AnnotationListView.swift` | 标注列表视图 |
| `Features/Sidebar/BookmarkListView.swift` | 书签列表视图 |
| `Features/Sidebar/ThumbnailGridView.swift` | 缩略图网格视图 |
| `Features/Sidebar/SidebarViewModel.swift` | 侧栏状态管理 |
| `Features/Sidebar/BookmarkService.swift` | 书签业务逻辑 |
| `Features/Sidebar/ThumbnailProvider.swift` | 缩略图生成 |
| `Shared/Models/BookmarkRecord.swift` | SwiftData 模型 |

---

## 覆盖映射

| PRD 类型 | PRD 编号 | 架构元素 | 状态 |
|---------|---------|---------|------|
| 功能需求 | FR-011 | AnnotationListView, API-060~062 | ✅ |
| 功能需求 | FR-012 | BookmarkListView, API-063~066 | ✅ |
| 功能需求 | FR-013 | ThumbnailGridView, API-067 | ✅ |
| 数据实体 | Entity-003 | DATA-003 BookmarkRecord | ✅ |
| 用户故事 | US-011 | API-060, API-061, API-062 | ✅ |
| 用户故事 | US-012 | API-063~066 | ✅ |
| 用户故事 | US-013 | API-067, ThumbnailGridView | ✅ |
| 验收标准 | AC-011-01~06 | 全部覆盖 | ✅ |
| 验收标准 | AC-012-01~07 | 全部覆盖 | ✅ |
| 验收标准 | AC-013-01~05 | 全部覆盖 | ✅ |
