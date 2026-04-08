# P-01: 项目骨架 + 数据层

## 文档信息

- **计划编号**: P-01
- **批次**: 第1批
- **对应架构**: docs/v1/02-architecture/01-overview.md, 05-data-spec.md
- **优先级**: P0
- **前置依赖**: 无

---

## 模块职责

搭建 Xcode 项目骨架，创建 SwiftData 数据模型，初始化持久化基础设施。这是所有后续模块的前提。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-01-01 | 创建 Xcode 项目 + 目录结构 | 3 | ~50 | - |
| T-01-02 | 定义共享类型与错误枚举 | 3 | ~80 | T-01-01 |
| T-01-03 | 实现 SwiftData 数据模型 | 3 | ~120 | T-01-02 |
| T-01-04 | 实现 PersistenceController | 1 | ~50 | T-01-03 |
| T-01-05 | 实现三个 Repository | 3 | ~180 | T-01-04 |
| T-01-06 | NSColor+Hex 扩展 | 1 | ~30 | T-01-01 |

---

## 详细任务定义

### T-01-01: 创建 Xcode 项目 + 目录结构

**任务概述**: 用 Xcode 创建 macOS App 项目，建立完整目录结构，配置最低版本和 Universal Binary。

**输出文件**:
- `PDF-Ve.xcodeproj`（Xcode 项目文件）
- `PDF-Ve/App/PDF_VeApp.swift`
- `PDF-Ve/App/AppDelegate.swift`

**实现要求**:

```swift
// PDF_VeApp.swift
import SwiftUI

@main
struct PDF_VeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // 菜单命令（后续任务填充）
        }
    }
}

// AppDelegate.swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
```

**Xcode 项目配置**:
- Bundle Identifier: `com.yourname.pdf-ve`
- Deployment Target: `macOS 13.0`
- Supported Architectures: `arm64 x86_64`（Universal Binary）
- Capabilities: 无需额外权限（本地文件读取通过 NSOpenPanel 即可）

**验收标准**:
- [ ] 项目可在 Xcode 中正常编译（零错误）
- [ ] 目录结构按规划创建完毕
- [ ] macOS 13.0 Deployment Target 已设置
- [ ] Universal Binary 已配置

**依赖**: 无

---

### T-01-02: 定义共享类型与错误枚举

**任务概述**: 定义全局共用的枚举类型（AnnotationType、AnnotationColor、DrawingLineWidth）和错误类型（FileError）。

**输出文件**:
- `PDF-Ve/Shared/Models/AnnotationTypes.swift`
- `PDF-Ve/Shared/Models/FileError.swift`
- `PDF-Ve/Shared/Models/OutlineItem.swift`

**实现要求**:

```swift
// AnnotationTypes.swift
import Foundation

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
    case yellow  = "#FFFF00"
    case green   = "#52C41A"
    case blue    = "#1890FF"
    case pink    = "#FF69B4"
    case orange  = "#FA8C16"
    case red     = "#FF4D4F"
    case black   = "#000000"
}

enum DrawingLineWidth: Double, CaseIterable, Codable {
    case thin   = 1.5
    case medium = 3.0
    case thick  = 6.0
}

enum AnnotationTool: Equatable {
    case none
    case highlight(color: AnnotationColor)
    case underline(color: AnnotationColor)
    case strikethrough(color: AnnotationColor)
    case note
    case drawing(color: AnnotationColor, lineWidth: DrawingLineWidth)
    case eraser
}

// FileError.swift
enum FileError: LocalizedError {
    case notFound
    case notFoundRemoved  // 从最近文件列表找不到，已自动移除
    case invalidPDF

    var errorDescription: String? {
        switch self {
        case .notFound:        return "文件不存在或已被移动"
        case .notFoundRemoved: return "文件已不存在，已从最近文件列表中移除"
        case .invalidPDF:      return "这不是有效的 PDF 文档"
        }
    }
}

// OutlineItem.swift
import Foundation

struct OutlineItem: Identifiable {
    let id: UUID
    let title: String
    let pageNumber: Int
    let depth: Int               // 1~5
    var children: [OutlineItem]
    var isExpanded: Bool = true

    init(title: String, pageNumber: Int, depth: Int, children: [OutlineItem] = []) {
        self.id = UUID()
        self.title = title
        self.pageNumber = pageNumber
        self.depth = depth
        self.children = children
    }
}
```

**验收标准**:
- [ ] 所有枚举编译通过
- [ ] `AnnotationType.displayName` 返回中文名称
- [ ] `FileError.errorDescription` 返回中文描述
- [ ] `OutlineItem` 满足 `Identifiable`

**依赖**: T-01-01

---

### T-01-03: 实现 SwiftData 数据模型

**任务概述**: 实现三个 SwiftData `@Model` 类：DocumentRecord、AnnotationRecord、BookmarkRecord。

**输出文件**:
- `PDF-Ve/Shared/Models/DocumentRecord.swift`
- `PDF-Ve/Shared/Models/AnnotationRecord.swift`
- `PDF-Ve/Shared/Models/BookmarkRecord.swift`

**实现要求**:

```swift
// DocumentRecord.swift
import SwiftData
import Foundation

@Model
final class DocumentRecord {
    var filePath: String
    var fileName: String
    var pageCount: Int
    var lastOpenedAt: Date
    var lastViewedPage: Int
    var zoomLevel: Double

    init(filePath: String, fileName: String, pageCount: Int) {
        self.filePath = filePath
        self.fileName = fileName
        self.pageCount = pageCount
        self.lastOpenedAt = Date()
        self.lastViewedPage = 1
        self.zoomLevel = 1.0
    }
}

// AnnotationRecord.swift
import SwiftData
import Foundation

@Model
final class AnnotationRecord {
    var id: UUID
    var documentPath: String
    var type: String            // AnnotationType.rawValue
    var pageNumber: Int
    var colorHex: String
    var content: String?
    var selectedText: String?
    var boundsX: Double
    var boundsY: Double
    var boundsWidth: Double
    var boundsHeight: Double
    var drawingPathData: Data?
    var createdAt: Date

    init(type: AnnotationType, documentPath: String, pageNumber: Int,
         colorHex: String, boundsX: Double, boundsY: Double,
         boundsWidth: Double, boundsHeight: Double) {
        self.id = UUID()
        self.type = type.rawValue
        self.documentPath = documentPath
        self.pageNumber = pageNumber
        self.colorHex = colorHex
        self.boundsX = boundsX
        self.boundsY = boundsY
        self.boundsWidth = boundsWidth
        self.boundsHeight = boundsHeight
        self.createdAt = Date()
    }

    var annotationType: AnnotationType {
        AnnotationType(rawValue: type) ?? .highlight
    }

    var bounds: CGRect {
        CGRect(x: boundsX, y: boundsY, width: boundsWidth, height: boundsHeight)
    }
}

// BookmarkRecord.swift
import SwiftData
import Foundation

@Model
final class BookmarkRecord {
    var id: UUID
    var documentPath: String
    var pageNumber: Int
    var name: String
    var createdAt: Date

    init(documentPath: String, pageNumber: Int) {
        self.id = UUID()
        self.documentPath = documentPath
        self.pageNumber = pageNumber
        self.name = "第\(pageNumber)页"
        self.createdAt = Date()
    }
}
```

**验收标准**:
- [ ] 三个 `@Model` 类编译无警告
- [ ] `AnnotationRecord.bounds` 计算属性返回正确 CGRect
- [ ] `AnnotationRecord.annotationType` 正确解析枚举
- [ ] `BookmarkRecord` 默认名称格式正确

**依赖**: T-01-02

---

### T-01-04: 实现 PersistenceController

**任务概述**: 创建 SwiftData ModelContainer，配置存储路径为 `~/Library/Application Support/PDF-Ve/PDFVe.store`。

**输出文件**:
- `PDF-Ve/Infrastructure/Persistence/PersistenceController.swift`

**实现要求**:

```swift
// PersistenceController.swift
import SwiftData
import Foundation

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

        // 存储路径：~/Library/Application Support/PDF-Ve/PDFVe.store
        guard let appSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Cannot access Application Support directory")
        }

        let storeDir = appSupportURL.appendingPathComponent("PDF-Ve")
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appendingPathComponent("PDFVe.store")
        let config = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // 测试用：内存数据库
    static func makeInMemory() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        return controller
    }

    private init(inMemory: Bool) {
        let schema = Schema([DocumentRecord.self, AnnotationRecord.self, BookmarkRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
    }
}
```

**验收标准**:
- [ ] `PersistenceController.shared` 可正常初始化
- [ ] 存储目录 `PDF-Ve/` 自动创建
- [ ] `makeInMemory()` 用于测试时正常工作

**依赖**: T-01-03

---

### T-01-05: 实现三个 Repository

**任务概述**: 实现 DocumentRepository、AnnotationRepository、BookmarkRepository，封装 SwiftData CRUD 操作。

**输出文件**:
- `PDF-Ve/Infrastructure/Persistence/DocumentRepository.swift`
- `PDF-Ve/Infrastructure/Persistence/AnnotationRepository.swift`
- `PDF-Ve/Infrastructure/Persistence/BookmarkRepository.swift`

**实现要求**:

```swift
// DocumentRepository.swift
import SwiftData
import Foundation

@MainActor
class DocumentRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 记录文件打开（新增或更新 lastOpenedAt）
    func recordOpen(filePath: String, fileName: String, pageCount: Int) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.lastOpenedAt = Date()
            existing.pageCount = pageCount
        } else {
            let record = DocumentRecord(filePath: filePath, fileName: fileName, pageCount: pageCount)
            context.insert(record)
            // 检查数量限制（Rule-004）
            try enforceMaxCount()
        }
        try context.save()
    }

    /// 最多保留20条，删除最旧的
    private func enforceMaxCount() throws {
        var descriptor = FetchDescriptor<DocumentRecord>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        if all.count > 20 {
            for record in all[20...] {
                context.delete(record)
            }
        }
    }

    /// 按 lastOpenedAt 降序返回最多20条
    func fetchRecent() throws -> [DocumentRecord] {
        var descriptor = FetchDescriptor<DocumentRecord>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        return try context.fetch(descriptor)
    }

    /// 更新阅读状态
    func updateReadingState(filePath: String, page: Int, zoom: Double) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        if let record = try context.fetch(descriptor).first {
            record.lastViewedPage = page
            record.zoomLevel = zoom
            try context.save()
        }
    }

    /// 删除记录（文件失效时）
    func remove(filePath: String) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }

    /// 获取阅读状态
    func readingState(for filePath: String) throws -> (page: Int, zoom: Double)? {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        guard let record = try context.fetch(descriptor).first else { return nil }
        return (page: record.lastViewedPage, zoom: record.zoomLevel)
    }
}

// AnnotationRepository.swift
@MainActor
class AnnotationRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func save(_ annotation: AnnotationRecord) throws {
        // upsert：检查 id 是否已存在
        let id = annotation.id
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if try context.fetch(descriptor).first == nil {
            context.insert(annotation)
        }
        try context.save()
    }

    func fetchAll(for documentPath: String) throws -> [AnnotationRecord] {
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.documentPath == documentPath },
            sortBy: [SortDescriptor(\.pageNumber), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }
}

// BookmarkRepository.swift
@MainActor
class BookmarkRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func save(_ bookmark: BookmarkRecord) throws {
        let id = bookmark.id
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if try context.fetch(descriptor).first == nil {
            context.insert(bookmark)
        }
        try context.save()
    }

    func fetchAll(for documentPath: String) throws -> [BookmarkRecord] {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.documentPath == documentPath },
            sortBy: [SortDescriptor(\.pageNumber)]
        )
        return try context.fetch(descriptor)
    }

    func findByPage(documentPath: String, pageNumber: Int) throws -> BookmarkRecord? {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.documentPath == documentPath && $0.pageNumber == pageNumber }
        )
        return try context.fetch(descriptor).first
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }

    func update(id: UUID, name: String) throws {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let record = try context.fetch(descriptor).first {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                record.name = String(trimmed.prefix(50))
            }
            try context.save()
        }
    }
}
```

**验收标准**:
- [ ] `DocumentRepository.enforceMaxCount()` 超过20条时正确删除最旧记录
- [ ] `AnnotationRepository.fetchAll()` 返回按 pageNumber 升序的列表
- [ ] `BookmarkRepository.update()` 空字符串时不更新名称

**依赖**: T-01-04

---

### T-01-06: NSColor+Hex 扩展

**任务概述**: 实现从 hex 字符串创建 NSColor 的扩展方法，用于标注颜色渲染。

**输出文件**:
- `PDF-Ve/Shared/Extensions/NSColor+Hex.swift`

**实现要求**:

```swift
// NSColor+Hex.swift
import AppKit

extension NSColor {
    convenience init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr = String(hexStr.dropFirst()) }
        guard hexStr.count == 6,
              let value = UInt64(hexStr, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    func withAlpha(_ alpha: CGFloat) -> NSColor {
        withAlphaComponent(alpha)
    }
}

extension Color {
    init?(hex: String) {
        guard let nsColor = NSColor(hex: hex) else { return nil }
        self.init(nsColor)
    }
}
```

**验收标准**:
- [ ] `NSColor(hex: "#FFFF00")` 返回黄色
- [ ] `NSColor(hex: "invalid")` 返回 nil
- [ ] `#` 前缀可选（有无均可解析）

**依赖**: T-01-01

---

## 验收清单

- [ ] 所有任务完成，项目编译零错误
- [ ] SwiftData 数据库可在 `~/Library/Application Support/PDF-Ve/` 下创建
- [ ] 三个 Repository 的基础 CRUD 功能正常
- [ ] Rule-004（最多20条最近文件）逻辑正确

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| DATA-001 DocumentRecord | T-01-03 | ✅ |
| DATA-002 AnnotationRecord | T-01-03 | ✅ |
| DATA-003 BookmarkRecord | T-01-03 | ✅ |
| PersistenceController | T-01-04 | ✅ |
| DocumentRepository | T-01-05 | ✅ |
| AnnotationRepository | T-01-05 | ✅ |
| BookmarkRepository | T-01-05 | ✅ |
| Rule-004 最近文件数量限制 | T-01-05 | ✅ |
