# 数据结构规约文档

## 文档信息

- **项目名称**: PDF-Ve
- **版本**: v1.0
- **对应PRD**: docs/v1/01-prd.md
- **更新日期**: 2026-04-01

---

## 数据实体清单

| 编号 | 实体名称 | 对应PRD实体 | 所属模块 | 持久化方式 |
|-----|---------|------------|---------|----------|
| DATA-001 | DocumentRecord | Entity-001 | MOD-01 | SwiftData |
| DATA-002 | AnnotationRecord | Entity-002 | MOD-05/06 | SwiftData |
| DATA-003 | BookmarkRecord | Entity-003 | MOD-07 | SwiftData |

---

## 实体详细定义

### DATA-001: DocumentRecord

**对应PRD**: Entity-001
**功能点**: FR-001, FR-015
**用户故事**: US-001, US-015

```swift
// Shared/Models/DocumentRecord.swift
@Model
final class DocumentRecord {
    // PRD属性: filePath
    var filePath: String        // 非空，PDF 文件绝对路径，UNIQUE

    // PRD属性: fileName
    var fileName: String        // 非空，文件名（不含路径）

    // PRD属性: pageCount
    var pageCount: Int          // 非空，> 0，总页数

    // PRD属性: lastOpenedAt
    var lastOpenedAt: Date      // 非空，最后打开时间

    // PRD属性: lastViewedPage
    var lastViewedPage: Int     // 默认 1，最后阅读页码

    // PRD属性: zoomLevel
    var zoomLevel: Double       // 默认 1.0，上次缩放比例（1.0 = 100%）

    init(filePath: String, fileName: String, pageCount: Int) {
        self.filePath = filePath
        self.fileName = fileName
        self.pageCount = pageCount
        self.lastOpenedAt = Date()
        self.lastViewedPage = 1
        self.zoomLevel = 1.0
    }
}
```

**字段规约**：

| 字段名 | PRD属性 | 类型 | 约束 | 默认值 | 说明 |
|-------|---------|------|------|-------|------|
| filePath | filePath | String | 非空，UNIQUE | - | PDF 文件绝对路径，作为文档唯一标识 |
| fileName | fileName | String | 非空 | - | 文件名，用于显示 |
| pageCount | pageCount | Int | 非空，> 0 | - | 总页数，打开时从 PDFDocument 读取 |
| lastOpenedAt | lastOpenedAt | Date | 非空 | Date() | 最近文件排序依据 |
| lastViewedPage | lastViewedPage | Int | 非空，>= 1 | 1 | 恢复阅读位置（Rule-002） |
| zoomLevel | zoomLevel | Double | 非空，0.1~5.0 | 1.0 | 恢复缩放比例（Rule-002） |

**关联关系**：
- 与 DATA-002（AnnotationRecord）：通过 `filePath` 关联，一对多
- 与 DATA-003（BookmarkRecord）：通过 `filePath` 关联，一对多

**索引设计**：

| 索引名 | 字段 | 类型 | 用途 |
|-------|------|------|------|
| idx_doc_filePath | filePath | UNIQUE | 文档唯一标识，按路径查找 |
| idx_doc_lastOpened | lastOpenedAt | 降序 | 最近文件列表排序（AC-015-01） |

**生命周期**：
- 创建：`FileService.openDocument()` 首次打开文件时创建；同一路径再次打开时更新 `lastOpenedAt`
- 更新：`FileService.closeDocument()` 时更新 `lastViewedPage`、`zoomLevel`
- 删除：Rule-003 触发（文件路径失效）或 Rule-004 触发（超过 20 条时删除最旧记录）

---

### DATA-002: AnnotationRecord

**对应PRD**: Entity-002
**功能点**: FR-006, FR-007, FR-008, FR-009, FR-010
**用户故事**: US-006~010

```swift
// Shared/Models/AnnotationRecord.swift
@Model
final class AnnotationRecord {
    // PRD属性: id
    var id: UUID                    // PK，唯一标识

    // PRD属性: documentPath
    var documentPath: String        // FK，所属文档绝对路径（对应 DocumentRecord.filePath）

    // PRD属性: type
    var type: AnnotationType        // highlight/underline/strikethrough/note/drawing

    // PRD属性: pageNumber
    var pageNumber: Int             // 所在页码（1-indexed），非空，> 0

    // PRD属性: color
    var colorHex: String            // 颜色 hex，如 "#FFFF00"，非空

    // PRD属性: content
    var content: String?            // 文字注释内容（note 类型使用），可空

    // PRD属性: selectedText
    var selectedText: String?       // 被标注的原文（highlight/underline/strikethrough 使用），可空

    // PRD属性: bounds（拆分为4个字段，SwiftData 不原生支持 CGRect）
    var boundsX: Double             // bounds.origin.x（PDF 坐标系，左下角为原点）
    var boundsY: Double             // bounds.origin.y
    var boundsWidth: Double         // bounds.size.width
    var boundsHeight: Double        // bounds.size.height

    // PRD属性: drawingData
    var drawingPathData: Data?      // 绘制路径 JSON 序列化数据（drawing 类型使用），可空

    // PRD属性: createdAt
    var createdAt: Date             // 创建时间，非空

    // 计算属性（不持久化）
    var bounds: CGRect {
        CGRect(x: boundsX, y: boundsY, width: boundsWidth, height: boundsHeight)
    }

    init(type: AnnotationType, documentPath: String, pageNumber: Int,
         colorHex: String, bounds: CGRect) {
        self.id = UUID()
        self.type = type
        self.documentPath = documentPath
        self.pageNumber = pageNumber
        self.colorHex = colorHex
        self.boundsX = bounds.origin.x
        self.boundsY = bounds.origin.y
        self.boundsWidth = bounds.size.width
        self.boundsHeight = bounds.size.height
        self.createdAt = Date()
    }
}

// Shared/Models/AnnotationTypes.swift
enum AnnotationType: String, Codable, CaseIterable {
    case highlight      = "highlight"
    case underline      = "underline"
    case strikethrough  = "strikethrough"
    case note           = "note"
    case drawing        = "drawing"

    var displayName: String {
        switch self {
        case .highlight:     return "高亮"
        case .underline:     return "下划线"
        case .strikethrough: return "删除线"
        case .note:          return "注释"
        case .drawing:       return "绘制"
        }
    }

    var systemImage: String {
        switch self {
        case .highlight:     return "highlighter"
        case .underline:     return "underline"
        case .strikethrough: return "strikethrough"
        case .note:          return "note.text"
        case .drawing:       return "pencil.tip"
        }
    }
}

enum AnnotationColor: String, CaseIterable, Codable {
    case yellow  = "#FFFF00"   // 高亮/标注默认色
    case green   = "#52C41A"
    case blue    = "#1890FF"
    case pink    = "#FF69B4"
    case orange  = "#FA8C16"
    case red     = "#FF4D4F"   // 画笔专用
    case black   = "#000000"   // 画笔专用

    var nsColor: NSColor { NSColor(hex: rawValue) ?? .yellow }
}

enum DrawingLineWidth: Double, CaseIterable {
    case thin   = 1.5
    case medium = 3.0
    case thick  = 6.0
}
```

**字段规约**：

| 字段名 | PRD属性 | 类型 | 约束 | 说明 |
|-------|---------|------|------|------|
| id | id | UUID | PK | 唯一标识 |
| documentPath | documentPath | String | 非空，有索引 | 关联文档路径 |
| type | type | String（Enum） | 非空，枚举值 | 标注类型 |
| pageNumber | pageNumber | Int | 非空，>= 1 | 所在页码 |
| colorHex | color | String | 非空，hex格式 | 标注颜色 |
| content | content | String? | 可空 | 仅 note 类型 |
| selectedText | selectedText | String? | 可空 | 仅文本标注类型 |
| boundsX/Y/W/H | bounds | Double × 4 | 非空 | PDF 坐标系位置 |
| drawingPathData | drawingData | Data? | 可空 | 仅 drawing 类型 |
| createdAt | createdAt | Date | 非空 | 创建时间 |

**关联关系**：
- 与 DATA-001（DocumentRecord）：多对一，通过 `documentPath = DocumentRecord.filePath`

**索引设计**：

| 索引名 | 字段 | 类型 | 用途 |
|-------|------|------|------|
| idx_ann_docPath | documentPath | 普通索引 | 按文档加载所有标注（API-051） |
| idx_ann_docPage | documentPath + pageNumber | 复合索引 | 按页码过滤标注（侧栏筛选） |

**drawingPathData 格式**（JSON）：
```json
{
  "points": [[x1, y1], [x2, y2], ...],
  "lineWidth": 3.0
}
```

**生命周期**：
- 创建：用户执行标注操作，`AnnotationService` 立即写入（Flow-002）
- 更新：`updateAnnotation()` 修改 content 或 bounds（便签拖动/编辑）
- 删除：`deleteAnnotation()`，包含用户主动删除和 undoLastDrawing

---

### DATA-003: BookmarkRecord

**对应PRD**: Entity-003
**功能点**: FR-012
**用户故事**: US-012

```swift
// Shared/Models/BookmarkRecord.swift
@Model
final class BookmarkRecord {
    // PRD属性: id
    var id: UUID                    // PK

    // PRD属性: documentPath
    var documentPath: String        // FK，所属文档路径

    // PRD属性: pageNumber
    var pageNumber: Int             // 书签页码（1-indexed），非空，> 0

    // PRD属性: name
    var name: String                // 书签名称，非空

    // PRD属性: createdAt
    var createdAt: Date             // 创建时间，非空

    init(documentPath: String, pageNumber: Int) {
        self.id = UUID()
        self.documentPath = documentPath
        self.pageNumber = pageNumber
        self.name = "第\(pageNumber)页"   // 默认名称（PRD: Entity-003 name默认值）
        self.createdAt = Date()
    }
}
```

**字段规约**：

| 字段名 | PRD属性 | 类型 | 约束 | 默认值 | 说明 |
|-------|---------|------|------|-------|------|
| id | id | UUID | PK | UUID() | 唯一标识 |
| documentPath | documentPath | String | 非空 | - | 关联文档路径 |
| pageNumber | pageNumber | Int | 非空，>= 1 | - | 书签页码 |
| name | name | String | 非空，长度 1~50 | "第X页" | 书签名称 |
| createdAt | createdAt | Date | 非空 | Date() | 创建时间 |

**约束**：
- 同一文档同一页码只能有一个书签（UNIQUE: documentPath + pageNumber）

**索引设计**：

| 索引名 | 字段 | 类型 | 用途 |
|-------|------|------|------|
| idx_bm_docPath | documentPath | 普通索引 | 加载文档书签列表 |
| idx_bm_docPage | documentPath + pageNumber | UNIQUE | 防止同页重复书签 |

**生命周期**：
- 创建：`BookmarkService.toggleBookmark()` 当该页无书签时创建
- 更新：`BookmarkService.renameBookmark()` 修改 name
- 删除：`BookmarkService.toggleBookmark()`（已有书签时删除）或 `deleteBookmark()`

---

## 非持久化数据结构

以下结构仅在运行时内存中使用，不持久化：

```swift
// ReaderState：MOD-02 ReaderViewModel 内部状态
struct ReaderState {
    var currentPage: Int = 1
    var totalPages: Int = 0
    var zoomLevel: Double = 1.0
    var zoomMode: ZoomMode = .actual
    var isFullscreen: Bool = false
}

// SearchState：MOD-04 SearchViewModel 内部状态
struct SearchState {
    var keyword: String = ""
    var results: [PDFSelection] = []
    var currentIndex: Int = 0
    var isSearchBarVisible: Bool = false
    var caseSensitive: Bool = false
    var isUnsearchable: Bool = false      // PDF 无可搜索文本
}

// OutlineItem：MOD-03 目录树节点
struct OutlineItem: Identifiable {
    let id: UUID
    let title: String
    let pageNumber: Int
    let depth: Int               // 1~5
    var children: [OutlineItem]
    var isExpanded: Bool = true
}

// ReadingState：FileService 返回的阅读状态
struct ReadingState {
    let lastPage: Int
    let zoomLevel: Double
}
```

---

## SwiftData ModelContainer 配置

```swift
// Infrastructure/Persistence/PersistenceController.swift

@MainActor
class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init() {
        let schema = Schema([
            DocumentRecord.self,
            AnnotationRecord.self,
            BookmarkRecord.self
        ])

        let storeURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("PDF-Ve/PDFVe.store")

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
```

---

## 覆盖映射

| PRD 类型 | PRD 编号 | 架构元素 | 状态 |
|---------|---------|---------|------|
| 数据实体 | Entity-001 | DATA-001 DocumentRecord | ✅ |
| 数据实体 | Entity-002 | DATA-002 AnnotationRecord | ✅ |
| 数据实体 | Entity-003 | DATA-003 BookmarkRecord | ✅ |
