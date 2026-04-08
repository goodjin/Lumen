# P-07: MOD-06 标注存储模块

## 文档信息

- **计划编号**: P-07
- **批次**: 第3批
- **对应架构**: docs/v1/02-architecture/03-mod06-storage.md
- **优先级**: P0
- **前置依赖**: P-01, P-06

---

## 模块职责

通过 SwiftData 持久化 AnnotationRecord、BookmarkRecord、DocumentRecord，执行 Rule-001（不修改原始 PDF），实现标注导出为 .txt。对应 PRD: FR-016, Rule-001, Flow-002。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-07-01 | 三个 Repository 完整实现 | 3 | ~150 | P-01 |
| T-07-02 | ExportService | 1 | ~80 | T-07-01 |
| T-07-03 | 导出菜单命令集成 | 1 | ~30 | T-07-02 |
| T-07-04 | AnnotationViewModel 接入存储 | 1 | ~40 | T-07-01, P-06 |

---

## 详细任务定义

### T-07-01: 三个 Repository 完整实现

**输出文件**:
- `PDF-Ve/Infrastructure/Persistence/AnnotationRepository.swift`
- `PDF-Ve/Infrastructure/Persistence/BookmarkRepository.swift`
- `PDF-Ve/Infrastructure/Persistence/DocumentRepository.swift`

**实现要求**:

```swift
// AnnotationRepository.swift
import SwiftData
import Foundation

@MainActor
class AnnotationRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // API-050: 保存标注（create or update）
    func save(_ annotation: AnnotationRecord) throws {
        // 先查找是否已存在
        let id = annotation.id
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            // 更新字段
            existing.content = annotation.content
            existing.colorHex = annotation.colorHex
            existing.boundsX = annotation.boundsX
            existing.boundsY = annotation.boundsY
            existing.boundsWidth = annotation.boundsWidth
            existing.boundsHeight = annotation.boundsHeight
            existing.strokeData = annotation.strokeData
        } else {
            context.insert(annotation)
        }
        try context.save()
    }

    // API-051: 加载文档所有标注（按页码升序）
    func fetchAll(for documentPath: String) -> [AnnotationRecord] {
        var descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.documentPath == documentPath },
            sortBy: [SortDescriptor(\.pageNumber)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // API-052: 删除标注
    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try? context.fetch(descriptor).first else { return }
        context.delete(record)
        try context.save()
    }

    func deleteAll(for documentPath: String) throws {
        let records = fetchAll(for: documentPath)
        records.forEach { context.delete($0) }
        try context.save()
    }
}

// BookmarkRepository.swift
import SwiftData
import Foundation

@MainActor
class BookmarkRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ bookmark: BookmarkRecord) throws {
        let id = bookmark.id
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.name = bookmark.name
        } else {
            context.insert(bookmark)
        }
        try context.save()
    }

    func fetchAll(for documentPath: String) -> [BookmarkRecord] {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.documentPath == documentPath },
            sortBy: [SortDescriptor(\.pageNumber)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try? context.fetch(descriptor).first else { return }
        context.delete(record)
        try context.save()
    }

    func find(documentPath: String, pageNumber: Int) -> BookmarkRecord? {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate {
                $0.documentPath == documentPath && $0.pageNumber == pageNumber
            }
        )
        return try? context.fetch(descriptor).first
    }
}

// DocumentRepository.swift（完整实现，补充 P-01 骨架）
import SwiftData
import Foundation

@MainActor
class DocumentRepository {
    private let context: ModelContext
    private let maxRecent = 20  // Rule-004

    init(context: ModelContext) {
        self.context = context
    }

    func recordOpen(filePath: String, fileName: String, pageCount: Int) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.lastOpenedAt = Date()
            existing.pageCount = pageCount
        } else {
            let record = DocumentRecord(filePath: filePath, fileName: fileName, pageCount: pageCount)
            context.insert(record)
            try pruneIfNeeded()
        }
        try context.save()
    }

    func fetchRecent() throws -> [DocumentRecord] {
        let descriptor = FetchDescriptor<DocumentRecord>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func updateReadingState(filePath: String, page: Int, zoom: Double) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        guard let record = try? context.fetch(descriptor).first else { return }
        record.lastPage = page
        record.lastZoom = zoom
        try context.save()
    }

    func readingState(for filePath: String) throws -> (page: Int, zoom: Double)? {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        guard let record = try? context.fetch(descriptor).first else { return nil }
        return (record.lastPage, record.lastZoom)
    }

    func remove(filePath: String) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        guard let record = try? context.fetch(descriptor).first else { return }
        context.delete(record)
        try context.save()
    }

    private func pruneIfNeeded() throws {
        var descriptor = FetchDescriptor<DocumentRecord>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        if all.count > maxRecent {
            all[maxRecent...].forEach { context.delete($0) }
        }
    }
}
```

**验收标准**:
- [ ] `save()` 对同 id 记录执行 update，不重复插入
- [ ] `fetchAll()` 结果按 pageNumber 升序
- [ ] `DocumentRepository.recordOpen()` 超过 20 条时自动删除最旧记录（Rule-004）
- [ ] 所有写操作均调用 `context.save()`，写入失败抛异常

---

### T-07-02: ExportService

**输出文件**: `PDF-Ve/Features/AnnotationStorage/ExportService.swift`

**实现要求**:

```swift
import Foundation

@MainActor
class ExportService {
    private let annotationRepo: AnnotationRepository

    init(annotationRepo: AnnotationRepository) {
        self.annotationRepo = annotationRepo
    }

    // API-053: 导出为文本
    func exportAnnotationsAsText(for documentPath: String) -> String {
        let annotations = annotationRepo.fetchAll(for: documentPath)
        guard !annotations.isEmpty else { return "" }

        return annotations.map { annotation in
            let typeLabel = annotation.type.exportLabel
            let content: String
            switch annotation.type {
            case .drawing:
                content = "手绘标记"
            default:
                content = annotation.content ?? ""
            }
            return "[第\(annotation.pageNumber)页] [\(typeLabel)] \(content)"
        }.joined(separator: "\n")
    }

    // 导出并保存为 .txt 文件
    func exportToFile(for documentPath: String, saveTo url: URL) throws {
        let text = exportAnnotationsAsText(for: documentPath)
        guard !text.isEmpty else {
            throw ExportError.noAnnotations
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

enum ExportError: LocalizedError {
    case noAnnotations
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noAnnotations:    return "当前文档无标注内容"
        case .permissionDenied: return "没有写入权限，请选择其他位置"
        }
    }
}

// AnnotationType 扩展：导出标签
extension AnnotationType {
    var exportLabel: String {
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
- [ ] 导出格式：`[第N页] [类型] 内容`，每条一行（AC-016-01）
- [ ] 按页码升序排列（AC-016-03）
- [ ] 无标注时返回空字符串，`exportToFile` 抛 `ExportError.noAnnotations`（AC-016-04）
- [ ] 绘制类标注输出「手绘标记」

---

### T-07-03: 导出菜单命令集成

在 `PDF_VeApp.swift` 的 `PDFVeCommands` 中添加「导出标注」菜单项，在 `MainWindowView` 中添加导出逻辑：

```swift
// PDFVeCommands 添加：
CommandGroup(after: .newItem) {
    Button("导出标注为文本…") {
        NotificationCenter.default.post(name: .exportAnnotations, object: nil)
    }
    .keyboardShortcut("e", modifiers: [.command, .shift])
    .disabled(!isDocumentLoaded)  // 无文档时禁用
}

extension Notification.Name {
    static let exportAnnotations = Notification.Name("exportAnnotations")
}

// MainWindowView 中监听并触发导出面板：
.onReceive(NotificationCenter.default.publisher(for: .exportAnnotations)) { _ in
    guard case .loaded(_, let url) = docVM.state else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.plainText]
    panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + "-标注"
    Task {
        guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK,
              let saveURL = panel.url else { return }
        do {
            try exportService.exportToFile(for: url.path, saveTo: saveURL)
        } catch ExportError.noAnnotations {
            // 显示提示：无标注内容
        } catch {
            // 显示权限错误
        }
    }
}
```

**验收标准**:
- [ ] 菜单「文件 > 导出标注为文本…」显示（AC-016-01）
- [ ] 触发 NSSavePanel，默认文件名为「文档名-标注.txt」（AC-016-02）
- [ ] 保存后可用文本编辑器查看内容

---

### T-07-04: AnnotationViewModel 接入存储

更新 `AnnotationViewModel`（P-06 T-06-02）以实际调用 `AnnotationRepository`：

```swift
// 在 AnnotationViewModel 中注入 repository
private let repository: AnnotationRepository

// loadAnnotations 实际从数据库加载
func loadAnnotations(for documentPath: String) {
    self.documentPath = documentPath
    annotations = repository.fetchAll(for: documentPath)
}

// createTextAnnotation 保存到数据库
func createTextAnnotation(type: AnnotationType, pageNumber: Int,
                           bounds: CGRect, content: String) {
    let record = AnnotationRecord(
        documentPath: documentPath,
        pageNumber: pageNumber,
        type: type,
        bounds: bounds,
        content: content,
        colorHex: selectedColor.hexString
    )
    try? repository.save(record)
    annotations = repository.fetchAll(for: documentPath)
}

// deleteAnnotation 从数据库删除
func deleteAnnotation(_ annotation: AnnotationRecord) {
    try? repository.delete(id: annotation.id)
    annotations = repository.fetchAll(for: documentPath)
}
```

**验收标准**:
- [ ] 打开文档后 `loadAnnotations` 从数据库正确加载历史标注（Flow-002）
- [ ] 新建标注后立即持久化（AC-006-04、AC-007-04、AC-008-03、AC-009-07、AC-010-05）
- [ ] 删除标注后数据库同步删除
- [ ] 关闭并重新打开文档，历史标注仍然显示

---

## 验收清单

- [ ] 所有标注操作（创建/修改/删除）立即写入数据库（< 100ms）
- [ ] 关闭文档后重新打开，标注完整恢复（Flow-002）
- [ ] 导出文本格式正确（AC-016-01 ~ AC-016-03）
- [ ] 无标注时导出给出提示（AC-016-04 异常处理）
- [ ] 最近文件列表不超过 20 条（Rule-004）
- [ ] 原始 PDF 文件字节不变（Rule-001）

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| API-050 save annotation | T-07-01 AnnotationRepository | ✅ |
| API-051 fetchAll | T-07-01 AnnotationRepository | ✅ |
| API-052 delete annotation | T-07-01 AnnotationRepository | ✅ |
| API-053 exportAnnotationsAsText | T-07-02 ExportService | ✅ |
| STATE-003 持久化状态机 | T-07-04 | ✅ |
| BOUND-030 写入边界 | T-07-01 | ✅ |
| BOUND-031 导出边界 | T-07-02 | ✅ |
| Rule-001 不修改原始 PDF | T-07-01（只写应用数据库） | ✅ |
| Flow-002 标注持久化流程 | T-07-01, T-07-04 | ✅ |
| FR-016 导出 .txt | T-07-02, T-07-03 | ✅ |
| AC-016-01~04 | T-07-02, T-07-03 | ✅ |
