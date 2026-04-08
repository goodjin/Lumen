# MOD-06: 标注存储模块

## 文档信息

- **模块编号**: MOD-06
- **版本**: v1.0
- **更新日期**: 2026-04-01
- **对应PRD**: FR-006~010（持久化部分）, FR-016, Rule-001, Flow-002
- **对应用户故事**: US-006~010（持久化验收）, US-016

---

## 系统定位

```
┌────────────────────────────────────────┐
│  MOD-05 AnnotationService              │
│  MOD-07 BookmarkService                │
│  MOD-01 FileService                    │
└─────────────────┬──────────────────────┘
                  │ ▼ 调用
┌─────────────────▼──────────────────────┐
│    ★ MOD-06: 标注存储模块 ★            │
│    AnnotationRepository                │
│    BookmarkRepository                  │
│    DocumentRepository                  │
│    ExportService                       │
└─────────────────┬──────────────────────┘
                  │ ▼ 依赖
┌─────────────────▼──────────────────────┐
│  SwiftData ModelContainer              │
│  （macOS 13 fallback: CoreData）       │
└────────────────────────────────────────┘
```

### 核心职责

- **持久化实现**：通过 SwiftData 将 AnnotationRecord、BookmarkRecord、DocumentRecord 写入本地数据库
- **Rule-001 执行**：所有写操作只操作应用数据库，从不修改原始 PDF 文件
- **Flow-002 实现**：文档打开时加载已有标注，标注操作后立即写入（< 100ms）
- **标注导出**：将标注数据序列化为纯文本（FR-016）

### 存储位置

```
~/Library/Application Support/PDF-Ve/
└── PDFVe.store            # SwiftData SQLite 数据库
```

不存储在 Documents 或 iCloud，不修改任何 PDF 文件。

---

## 对应 PRD

| PRD 编号 | 内容 |
|---------|------|
| Rule-001 | 标注不修改原始 PDF，存储到应用专属目录 |
| Flow-002 | 标注持久化流程 |
| FR-016 | 标注导出为 .txt |
| US-016 | 导出标注 |
| AC-006-04 | 高亮标注持久化保存 |
| AC-007-04 | 下划线持久化保存 |
| AC-008-03 | 删除线持久化保存 |
| AC-009-07 | 注释持久化保存 |
| AC-010-05 | 绘制内容持久化保存 |
| AC-012-06 | 书签持久化保存 |
| AC-016-01~04 | 标注导出验收条件 |

---

## 接口定义

### API-050: 保存标注

```swift
// AnnotationRepository
func save(_ annotation: AnnotationRecord) throws
// 立即写入（< 100ms，对应性能需求）
// 若已存在同 id 记录则覆盖（update 语义）
```

### API-051: 加载文档的所有标注

**对应 PRD**: Flow-002

```swift
// AnnotationRepository
func fetchAll(for documentPath: String) -> [AnnotationRecord]
// 按 pageNumber 升序排列
// 文档打开时调用，加载后渲染到 AnnotationOverlayView
```

### API-052: 删除标注

```swift
// AnnotationRepository
func delete(id: UUID) throws
```

### API-053: 导出标注为文本

**对应 PRD**: FR-016, AC-016-01~04

```swift
// ExportService
func exportAnnotationsAsText(for documentPath: String) -> String
```

**输出格式**：
```
[第1页] [高亮] 被标注的文字内容
[第2页] [注释] 便签文字内容
[第3页] [下划线] 被标注的文字
[第3页] [绘制] 手绘标记
```

**排序**：按 `pageNumber` 升序（AC-016-03）

**空标注处理**：返回空字符串，调用方判断并提示（AC-016-04 异常）

---

## 数据结构

### 持久化存储路径

```swift
// Infrastructure/Persistence/PersistenceController.swift
static let storeURL = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("PDF-Ve/PDFVe.store")
```

### 索引设计（SwiftData / CoreData）

**AnnotationRecord 索引**：

| 索引名 | 字段 | 类型 | 用途 |
|-------|------|------|------|
| idx_doc_path | documentPath | 普通索引 | 按文档路径查询全部标注 |
| idx_page | documentPath + pageNumber | 复合索引 | 按页码过滤 |

**DocumentRecord 索引**：

| 索引名 | 字段 | 类型 | 用途 |
|-------|------|------|------|
| idx_file_path | filePath | UNIQUE | 文件路径唯一约束 |
| idx_last_opened | lastOpenedAt | 降序索引 | 最近文件排序 |

---

## 状态机设计

### STATE-003: 标注持久化状态机

**对应 PRD**: Flow-002

```
┌──────────────┐  文档打开，fetchAll()   ┌──────────────────┐
│  文档未打开   │ ─────────────────────▶ │  标注已加载到内存  │
└──────────────┘                        └────────┬─────────┘
                                                 │ 用户操作（创建/修改/删除）
                                                 ▼
                                        ┌──────────────────┐
                                        │  立即触发 save()  │
                                        │  （< 100ms 写入） │
                                        └────────┬─────────┘
                                                 │ 写入完成
                                                 ▼
                                        ┌──────────────────┐
                                        │  持久化已完成     │
                                        └──────────────────┘
```

---

## 边界条件

### BOUND-030: 持久化写入边界

| 条件 | 处理 |
|-----|------|
| 写入失败（磁盘满等） | 捕获异常，在 UI 层显示错误提示，不崩溃 |
| 数据库文件被外部删除 | 下次操作时重新创建数据库文件，已有标注丢失（可接受，个人工具） |

### BOUND-031: 导出边界

| 条件 | 处理 |
|-----|------|
| 无标注时导出 | 返回空字符串，ExportService 调用方显示「当前文档无标注内容」提示（AC-016-04 异常） |
| 导出路径无写权限 | 抛 `ExportError.permissionDenied`，UI 层提示 |

---

## 实现文件

| 文件路径 | 职责 |
|---------|------|
| `Infrastructure/Persistence/PersistenceController.swift` | SwiftData ModelContainer 初始化 |
| `Infrastructure/Persistence/AnnotationRepository.swift` | 标注 CRUD |
| `Infrastructure/Persistence/BookmarkRepository.swift` | 书签 CRUD |
| `Infrastructure/Persistence/DocumentRepository.swift` | 文档记录 CRUD |
| `Features/AnnotationStorage/ExportService.swift` | 导出逻辑 |

---

## 覆盖映射

| PRD 类型 | PRD 编号 | 架构元素 | 状态 |
|---------|---------|---------|------|
| 业务规则 | Rule-001 | 存储路径设计，不写 PDF 文件 | ✅ |
| 业务流程 | Flow-002 | STATE-003, API-050, API-051 | ✅ |
| 功能需求 | FR-016 | API-053, ExportService | ✅ |
| 用户故事 | US-016 | API-053 | ✅ |
| 验收标准 | AC-006-04 | API-050 | ✅ |
| 验收标准 | AC-007-04 | API-050 | ✅ |
| 验收标准 | AC-008-03 | API-050 | ✅ |
| 验收标准 | AC-009-07 | API-050 | ✅ |
| 验收标准 | AC-010-05 | API-050 | ✅ |
| 验收标准 | AC-012-06 | BookmarkRepository.save() | ✅ |
| 验收标准 | AC-016-01~04 | API-053, BOUND-031 | ✅ |
