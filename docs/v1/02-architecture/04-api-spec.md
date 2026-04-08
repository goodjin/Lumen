# 接口规约文档

## 文档信息

- **项目名称**: PDF-Ve
- **版本**: v1.0
- **对应PRD**: docs/v1/01-prd.md
- **更新日期**: 2026-04-01

> **说明**：PDF-Ve 是 macOS 单机应用，无 HTTP API。本文档的「接口」指模块间的 Swift 函数调用契约，包含方法签名、前置条件、边界行为、错误处理。

---

## 接口清单

| 编号 | 接口名称 | 所属模块 | 对应用户故事 |
|-----|---------|---------|------------|
| API-001 | openDocument(at:) | MOD-01 FileService | US-001 |
| API-002 | closeDocument(at:currentPage:zoomLevel:) | MOD-01 FileService | US-001 (Rule-002) |
| API-003 | recentDocuments() | MOD-01 FileService | US-015 |
| API-004 | openRecentDocument(_:) | MOD-01 FileService | US-015 |
| API-005 | readingState(for:) | MOD-01 FileService | US-001 (Rule-002) |
| API-010 | goToPage(_:) | MOD-02 ReaderViewModel | US-002 |
| API-011 | setZoom(_:) / zoomIn() / zoomOut() / setZoomMode(_:) | MOD-02 ReaderViewModel | US-003 |
| API-012 | toggleFullscreen() | MOD-02 ReaderViewModel | US-014 |
| API-020 | loadOutline(from:) | MOD-03 SidebarViewModel | US-004 |
| API-021 | selectOutlineItem(_:) | MOD-03 SidebarViewModel | US-004 |
| API-030 | search(keyword:in:caseSensitive:) | MOD-04 SearchService | US-005 |
| API-031 | nextMatch() | MOD-04 SearchViewModel | US-005 |
| API-032 | previousMatch() | MOD-04 SearchViewModel | US-005 |
| API-033 | dismissSearch() | MOD-04 SearchViewModel | US-005 |
| API-040 | createTextAnnotation(...) | MOD-05 AnnotationService | US-006, US-007, US-008 |
| API-041 | createNoteAnnotation(...) | MOD-05 AnnotationService | US-009 |
| API-042 | updateAnnotation(...) | MOD-05 AnnotationService | US-009 |
| API-043 | deleteAnnotation(id:) | MOD-05 AnnotationService | US-006~010 |
| API-044 | appendDrawingStroke(...) | MOD-05 AnnotationService | US-010 |
| API-045 | undoLastDrawing() | MOD-05 AnnotationViewModel | US-010 |
| API-050 | save(_:) | MOD-06 AnnotationRepository | US-006~010 |
| API-051 | fetchAll(for:) | MOD-06 AnnotationRepository | US-011 |
| API-052 | delete(id:) | MOD-06 AnnotationRepository | US-006~010 |
| API-053 | exportAnnotationsAsText(for:) | MOD-06 ExportService | US-016 |
| API-060 | annotations (computed) | MOD-07 SidebarViewModel | US-011 |
| API-061 | filterAnnotations(by:) | MOD-07 SidebarViewModel | US-011 |
| API-062 | selectAnnotation(_:) | MOD-07 SidebarViewModel | US-011 |
| API-063 | toggleBookmark(at:in:) | MOD-07 BookmarkService | US-012 |
| API-064 | renameBookmark(id:name:) | MOD-07 BookmarkService | US-012 |
| API-065 | selectBookmark(_:) | MOD-07 SidebarViewModel | US-012 |
| API-066 | deleteBookmark(id:) | MOD-07 BookmarkService | US-012 |
| API-067 | thumbnail(for:size:) | MOD-07 ThumbnailProvider | US-013 |

---

## 接口详细定义

### API-001: openDocument(at:)

**对应PRD**: US-001, AC-001-01 ~ AC-001-05

```swift
// FileService.swift
func openDocument(at url: URL) async throws -> PDFDocument
```

**前置条件**：
- `url.pathExtension` 大小写不敏感等于 `"pdf"`
- 当前应用有读取该路径的权限

**行为**：
1. 检查文件存在性，不存在 → 抛 `FileError.notFound`
2. 调用 `PDFDocument(url: url)` 加载，返回 nil → 抛 `FileError.invalidPDF`
3. 调用 `DocumentRepository.recordOpen(url:pageCount:)` 更新最近文件
4. 返回 `PDFDocument`

**错误处理**：

| 错误 | 场景 | AC |
|-----|------|-----|
| `FileError.notFound` | 文件路径不存在 | AC-001-05 |
| `FileError.invalidPDF` | 文件不是有效 PDF / 损坏 | AC-001-05 |

**后置影响**：DocumentRepository 中该文件记录的 `lastOpenedAt` 更新

---

### API-002: closeDocument(at:currentPage:zoomLevel:)

**对应PRD**: Rule-002

```swift
func closeDocument(at url: URL, currentPage: Int, zoomLevel: Double)
```

**行为**：调用 `DocumentRepository.updateReadingState(filePath:page:zoom:)` 同步写入，无错误抛出

---

### API-003: recentDocuments()

**对应PRD**: US-015, AC-015-01 ~ AC-015-03

```swift
func recentDocuments() -> [DocumentRecord]
```

**返回**：按 `lastOpenedAt` 降序，最多 20 条（Rule-004）

---

### API-004: openRecentDocument(_:)

**对应PRD**: US-015, AC-015-04 ~ AC-015-05, Rule-003

```swift
func openRecentDocument(_ record: DocumentRecord) async throws -> PDFDocument
```

**行为**：
1. `FileManager.default.fileExists(atPath: record.filePath)` 为 false → `DocumentRepository.remove(record)` → 抛 `FileError.notFoundRemoved`（区别于普通 notFound，表示已从列表移除）
2. 否则走 API-001 逻辑

---

### API-010: goToPage(_:)

**对应PRD**: US-002, AC-002-04

```swift
// ReaderViewModel.swift
func goToPage(_ pageNumber: Int)
```

**行为**：`clamp(pageNumber, 1...totalPages)` 后调用 `PDFView.go(to: page)`

**边界**：
- `pageNumber < 1` → 跳转到第 1 页
- `pageNumber > totalPages` → 跳转到最后一页

**后置影响（必填）**：
- **直接变更**：`ReaderViewModel.currentPage: 旧页码 → 新页码`
- **级联影响分析**（所有订阅 `currentPage` 变更的模块）：
  | 订阅模块 | 监听方式 | 触发动作 |
  |---------|---------|---------|
  | `ThumbnailGridView` | `.onChange(of: readerVM.currentPage)` | 滚动到当前页缩略图并更新蓝色边框（AC-013-03） |
  | `ToolbarView` | `@Bindable` 绑定 | 更新页码输入框显示 |
  | `BookmarkListView` | 通过视图刷新 | 更新当前页书签图标状态（如已书签则高亮） |
  | `AnnotationOverlayView` | 通过 `pdfView.currentPage` | 刷新当前页标注覆盖层 |
  | `DocumentRepository` | 异步延迟保存 | 更新 `lastViewedPage` 到数据库（Rule-002） |
  | `SearchViewModel` | 页面变更回调 | 清除搜索高亮（如存在） |

---

## View 层交互接口（新增）

以下接口定义用户手势到 ViewModel 的调用链，细化到具体交互方式。

### VIEW-API-001: 目录项点击跳转

**对应PRD**: US-004, AC-004-02

**手势**: 单击 (Tap)
**触发源**: `OutlineView.List` 中的 `OutlineItemRow`

**调用链**：
```
OutlineItemRow.onTapGesture
  → OutlineViewModel.selectItem(item, readerVM)
    → ReaderViewModel.goToPage(item.pageNumber)
```

**参数**：
| 参数 | 类型 | 说明 |
|-----|------|------|
| `item` | `OutlineItem` | 点击的目录项，包含 `pageNumber` |
| `readerVM` | `ReaderViewModel` | 用于执行页面跳转 |

**后置影响**：同 API-010 级联影响

---

### VIEW-API-002: 缩略图点击跳转

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

### API-011: 缩放系列

**对应PRD**: US-003, AC-003-01 ~ AC-003-07

```swift
func zoomIn()                         // scaleFactor = min(scaleFactor + 0.1, 5.0)
func zoomOut()                        // scaleFactor = max(scaleFactor - 0.1, 0.1)
func setZoom(_ level: Double)         // scaleFactor = clamp(level, 0.1...5.0)
func setZoomMode(_ mode: ZoomMode)    // 切换适合宽度/适合页面/实际大小
```

**边界**：缩放范围 `[0.1, 5.0]`，超出范围时静默 clamp，不抛错误（AC-003-06）

---

### API-030: search(keyword:in:caseSensitive:)

**对应PRD**: US-005, AC-005-01 ~ AC-005-07

```swift
// SearchService.swift
func search(keyword: String, in document: PDFDocument, caseSensitive: Bool = false) -> [PDFSelection]
```

**前置条件**：`keyword` 非空（空时直接返回 `[]`）

**行为**：
- 构造 `NSString.CompareOptions`：`.caseInsensitive`（默认）
- 调用 `document.findString(keyword, withOptions:)`
- 返回所有匹配的 `[PDFSelection]`

**边界**：
- `keyword.count > 100` → 截断到前 100 字符
- PDF 无可搜索文本 → PDFKit 返回 `[]`，SearchViewModel 检测并设置 `isUnsearchable = true`

---

### API-040: createTextAnnotation(type:selection:color:in:)

**对应PRD**: US-006, US-007, US-008, AC-006-01 ~ AC-006-05, AC-007-01~04, AC-008-01~03

```swift
// AnnotationService.swift
func createTextAnnotation(
    type: AnnotationType,
    selection: PDFSelection,
    color: AnnotationColor,
    in document: PDFDocument
) throws -> AnnotationRecord
```

**前置条件**：
- `selection` 包含可识别的文本字符（`selection.string != nil && !selection.string!.isEmpty`）
- `type` 为 `.highlight` / `.underline` / `.strikethrough` 之一

**行为**：
1. 从 `PDFSelection` 提取第一页的 `bounds` 和 `pageNumber`
2. 提取 `selectedText = selection.string`
3. 创建 `AnnotationRecord(type:, documentPath:, pageNumber:, colorHex:, selectedText:, bounds:)`
4. 调用 `AnnotationRepository.save(record)`
5. 返回 `record`

**错误**：
- `AnnotationError.noSelectableText`：选中区域无可识别文本（AC-006 异常）

---

### API-041: createNoteAnnotation(at:pageNumber:content:in:)

**对应PRD**: US-009, AC-009-01 ~ AC-009-07

```swift
func createNoteAnnotation(
    at point: CGPoint,
    pageNumber: Int,
    content: String = "",
    in document: PDFDocument
) -> AnnotationRecord
```

**行为**：创建 `type = .note`，`bounds = CGRect(origin: point, size: CGSize(width: 200, height: 100))`，立即持久化

---

### API-042: updateAnnotation(id:content:bounds:)

**对应PRD**: US-009 AC-009-02, AC-009-04

```swift
func updateAnnotation(id: UUID, content: String? = nil, bounds: CGRect? = nil)
```

**行为**：按 id 查找记录，更新非 nil 字段，调用 `AnnotationRepository.save()`（覆盖写）

---

### API-043: deleteAnnotation(id:)

**对应PRD**: AC-006-05, AC-009-08, AC-011-06

```swift
func deleteAnnotation(id: UUID)
```

**行为**：调用 `AnnotationRepository.delete(id:)`，AnnotationViewModel 同步从内存集合移除

---

### API-044: appendDrawingStroke(path:color:lineWidth:pageNumber:)

**对应PRD**: US-010, AC-010-01 ~ AC-010-05

```swift
func appendDrawingStroke(
    path: [CGPoint],
    color: AnnotationColor,
    lineWidth: DrawingLineWidth,
    pageNumber: Int
) -> AnnotationRecord
```

**前置条件**：`path.count >= 2`（不足 2 个点不构成线条，静默忽略）

**行为**：
1. 将 `path` 序列化为 `Data`（JSON 编码 `[[Double]]` 格式）
2. 创建 `type = .drawing` 的 `AnnotationRecord`，`drawingPathData = data`
3. 调用 `AnnotationRepository.save()`

---

### API-045: undoLastDrawing()

**对应PRD**: AC-010-04

```swift
// AnnotationViewModel.swift
func undoLastDrawing()
```

**行为**：找到 `annotations` 中最后一条 `type == .drawing` 的记录，调用 `deleteAnnotation(id:)`

**边界**：无 drawing 类型标注时，静默无操作

---

### API-050: AnnotationRepository.save(_:)

**对应PRD**: Rule-001, AC-006-04, AC-007-04, AC-008-03, AC-009-07, AC-010-05

```swift
// AnnotationRepository.swift
func save(_ annotation: AnnotationRecord) throws
```

**行为**：SwiftData `modelContext.insert()` 或 upsert（按 id）后 `try modelContext.save()`

**性能要求**：完成时间 < 100ms（PRD 性能需求 3.1）

---

### API-051: AnnotationRepository.fetchAll(for:)

**对应PRD**: Flow-002, AC-011-01, AC-011-02

```swift
func fetchAll(for documentPath: String) -> [AnnotationRecord]
```

**返回**：按 `pageNumber` 升序排列的所有标注

---

### API-053: ExportService.exportAnnotationsAsText(for:)

**对应PRD**: FR-016, AC-016-01 ~ AC-016-04

```swift
// ExportService.swift
func exportAnnotationsAsText(for documentPath: String) -> String
```

**输出格式**（按 pageNumber 升序，AC-016-03）：
```
[第1页] [高亮] 重要的文字内容
[第2页] [注释] 这里有一个值得关注的点
[第3页] [下划线] 另一段重要内容
[第3页] [绘制] 手绘标记
```

**边界**：无标注时返回空字符串（AC-016-04 异常由调用方处理）

---

### API-067: ThumbnailProvider.thumbnail(for:size:)

**对应PRD**: US-013, AC-013-01 ~ AC-013-05

```swift
// ThumbnailProvider.swift
func thumbnail(for page: PDFPage, size: CGSize) async -> NSImage
```

**行为**：调用 `PDFPage.thumbnail(of: size, for: .mediaBox)` 在后台线程生成

**性能**：async，不阻塞主线程，LazyVGrid 只请求可见区域内的缩略图（AC-013-05）
