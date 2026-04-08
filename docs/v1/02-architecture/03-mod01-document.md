# MOD-01: 文件管理模块

## 文档信息

- **模块编号**: MOD-01
- **版本**: v1.0
- **更新日期**: 2026-04-01
- **对应PRD**: FR-001, FR-015, Rule-002, Rule-003, Rule-004
- **对应用户故事**: US-001, US-015

---

## 系统定位

### 在整体架构中的位置

**所属层次**: L3 业务逻辑层（FileService）+ L2 数据访问层（DocumentRepository）

```
┌────────────────────────────────────────┐
│  L5: MainWindowView / RecentFilesView  │
│  L4: DocumentViewModel                 │
└────────────────────┬───────────────────┘
                     │ ▼ 调用
┌────────────────────▼───────────────────┐
│       ★ MOD-01: FileService ★          │
└────────────────────┬───────────────────┘
                     │ ▼ 依赖
┌────────────────────▼───────────────────┐
│  DocumentRepository / FileManager      │
│  PDFKit.PDFDocument（校验用）           │
└────────────────────────────────────────┘
```

### 核心职责

- **文件打开**：接受来自菜单、拖拽、文件关联的打开请求，校验文件有效性，通知 ViewModel 加载
- **最近文件管理**：记录打开历史，维护不超过 20 条的最近文件列表（Rule-004）
- **阅读位置记忆**：文档关闭时保存当前页码和缩放比例（Rule-002）
- **失效文件处理**：打开最近文件前检查文件是否存在，失效时移除记录（Rule-003）

### 边界说明

- **负责**：文件路径管理、PDF 文件有效性校验、最近文件 CRUD、阅读状态持久化
- **不负责**：PDF 内容渲染（MOD-02 负责）、标注数据（MOD-05/06 负责）

---

## 对应 PRD

| PRD 章节 | 编号 | 内容 |
|---------|-----|------|
| 功能需求 | FR-001 | PDF 文件打开，支持菜单/拖拽/文件关联 |
| 功能需求 | FR-015 | 最近文件，最多 20 条，快速访问 |
| 用户故事 | US-001 | 打开 PDF 文件 |
| 用户故事 | US-015 | 最近文件列表 |
| 业务规则 | Rule-002 | 关闭时保存阅读位置 |
| 业务规则 | Rule-003 | 最近文件路径失效处理 |
| 业务规则 | Rule-004 | 最近文件数量上限 20 条 |
| 验收标准 | AC-001-01~05 | 文件打开的全部验收条件 |
| 验收标准 | AC-015-01~05 | 最近文件的全部验收条件 |

---

## 依赖关系

### 上游依赖（被调用方向）

| 调用者 | 场景 |
|-------|------|
| DocumentViewModel | 用户触发打开文件、关闭文档、查看最近文件 |

### 下游依赖

| 依赖项 | 用途 |
|-------|------|
| DocumentRepository | 读写 Document 记录（最近文件、阅读状态） |
| Foundation.FileManager | 检查文件路径是否存在 |
| PDFKit.PDFDocument | 加载 PDF 校验其有效性 |

---

## 接口定义

### API-001: 打开 PDF 文件

**对应 PRD**: US-001, AC-001-01 ~ AC-001-05

```swift
// FileService
func openDocument(at url: URL) async throws -> PDFDocument
```

**行为**：
1. 检查 `url.pathExtension == "pdf"`（不区分大小写）
2. 检查 `FileManager.default.fileExists(atPath:)` → 不存在抛 `FileError.notFound`
3. 调用 `PDFDocument(url:)` → 返回 `nil` 时抛 `FileError.invalidPDF`
4. 调用 `DocumentRepository.recordOpen(url:pageCount:)` 更新最近文件
5. 返回 `PDFDocument`

**错误类型**：

| 错误 | 场景 | 对应AC |
|-----|------|-------|
| `FileError.notFound` | 文件路径不存在 | AC-001-05 |
| `FileError.invalidPDF` | 文件不是有效 PDF | AC-001-05 |

---

### API-002: 记录文档关闭状态（阅读位置）

**对应 PRD**: Rule-002

```swift
// FileService
func closeDocument(at url: URL, currentPage: Int, zoomLevel: Double)
```

**行为**：
1. 调用 `DocumentRepository.updateReadingState(filePath:page:zoom:)`
2. 同步写入，无返回值

---

### API-003: 获取最近文件列表

**对应 PRD**: US-015, AC-015-01 ~ AC-015-03

```swift
// FileService
func recentDocuments() -> [DocumentRecord]
// 返回按 lastOpenedAt 降序排列的最多 20 条记录
```

---

### API-004: 打开最近文件（含路径校验）

**对应 PRD**: US-015, AC-015-04 ~ AC-015-05, Rule-003

```swift
// FileService
func openRecentDocument(_ record: DocumentRecord) async throws -> PDFDocument
```

**行为**：
1. 检查 `FileManager.default.fileExists(atPath: record.filePath)`
2. 不存在 → 调用 `DocumentRepository.remove(record)` → 抛 `FileError.notFound`
3. 存在 → 走 API-001 逻辑

---

### API-005: 获取文档上次阅读状态

**对应 PRD**: Rule-002

```swift
// FileService
func readingState(for url: URL) -> ReadingState?
// ReadingState: (lastPage: Int, zoomLevel: Double)
```

---

## 数据结构

### DATA-001: DocumentRecord

**对应 PRD**: Entity-001

```swift
@Model
final class DocumentRecord {
    var filePath: String        // 非空，PDF 文件绝对路径
    var fileName: String        // 非空，文件名（不含路径）
    var pageCount: Int          // 非空，> 0
    var lastOpenedAt: Date      // 非空，最后打开时间
    var lastViewedPage: Int     // 默认 1，最后阅读页码
    var zoomLevel: Double       // 默认 1.0，上次缩放比例

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

**索引设计**：

| 索引名 | 字段 | 类型 | 用途 |
|-------|------|------|------|
| idx_filePath | filePath | UNIQUE | 按文件路径查找/去重 |
| idx_lastOpenedAt | lastOpenedAt | 降序 | 最近文件列表排序 |

---

## 状态机设计

### STATE-001: 文档打开状态机

**对应 PRD**: Flow-002（标注持久化流程中的文档打开阶段）

```
┌──────────────┐   openDocument()   ┌──────────────┐
│    未打开     │ ─────────────────▶ │   加载中      │
└──────────────┘                    └──────┬───────┘
                                           │ 成功
                                           ▼
                                    ┌──────────────┐   closeDocument()   ┌──────────────┐
                                    │   已打开      │ ──────────────────▶ │    未打开     │
                                    └──────────────┘                     └──────────────┘
                                           │ 失败（抛出错误）
                                           ▼
                                    ┌──────────────┐
                                    │   打开失败    │
                                    └──────────────┘
```

---

## 边界条件

### BOUND-001: 文件打开边界

**对应 PRD**: AC-001-04, AC-001-05

| 条件 | 处理方式 |
|-----|---------|
| 文件不存在 | 抛 `FileError.notFound`，UI 层显示错误对话框 |
| 非 PDF 文件 | 抛 `FileError.invalidPDF` |
| PDF 文件损坏（PDFDocument 返回 nil） | 抛 `FileError.invalidPDF` |
| 文件大小 > 500MB | 允许打开，性能不保证（PRD 性能要求针对 100MB 以内） |
| 文件大小 0 字节 | `PDFDocument` 初始化失败，抛 `FileError.invalidPDF` |

### BOUND-002: 最近文件数量边界

**对应 PRD**: Rule-004, AC-015-01

| 条件 | 处理方式 |
|-----|---------|
| 新增记录后总数 > 20 | 删除 `lastOpenedAt` 最小的记录，保持 ≤ 20 条 |
| 同一文件重复打开 | 更新已有记录的 `lastOpenedAt`，不新增条目 |

### BOUND-003: 页码范围边界

**对应 PRD**: AC-002-04

| 条件 | 处理方式 |
|-----|---------|
| 恢复阅读位置时，`lastViewedPage > pageCount`（文件被替换） | 跳转到第 1 页 |

---

## 非功能需求

| 指标 | 要求 | 对应 PRD |
|-----|------|---------|
| 文件打开响应 | 100MB 内 PDF < 3 秒 | 性能需求 3.1 |
| 最近文件写入 | < 100ms | 性能需求 3.1（标注保存延迟参考） |

---

## 实现文件

| 文件路径 | 职责 |
|---------|------|
| `Features/Document/FileService.swift` | FileService 实现 |
| `Features/Document/DocumentViewModel.swift` | DocumentViewModel |
| `Features/Document/RecentFilesView.swift` | 最近文件启动页视图 |
| `Infrastructure/Persistence/DocumentRepository.swift` | Repository 实现 |
| `Shared/Models/DocumentRecord.swift` | SwiftData 模型 |
| `Shared/Models/FileError.swift` | 错误类型定义 |

---

## 覆盖映射

| PRD 类型 | PRD 编号 | 架构元素 | 状态 |
|---------|---------|---------|------|
| 功能需求 | FR-001 | API-001, MOD-01 | ✅ |
| 功能需求 | FR-015 | API-003, API-004, MOD-01 | ✅ |
| 用户故事 | US-001 | API-001 | ✅ |
| 用户故事 | US-015 | API-003, API-004 | ✅ |
| 数据实体 | Entity-001 | DATA-001 DocumentRecord | ✅ |
| 业务规则 | Rule-002 | API-002, STATE-001 | ✅ |
| 业务规则 | Rule-003 | API-004, BOUND-002 | ✅ |
| 业务规则 | Rule-004 | BOUND-002 | ✅ |
| 验收标准 | AC-001-01~05 | API-001, BOUND-001 | ✅ |
| 验收标准 | AC-015-01~05 | API-003, API-004, BOUND-002 | ✅ |
