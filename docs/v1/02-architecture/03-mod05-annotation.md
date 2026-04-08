# MOD-05: 标注模块

## 文档信息

- **模块编号**: MOD-05
- **版本**: v1.0
- **更新日期**: 2026-04-01
- **对应PRD**: FR-006, FR-007, FR-008, FR-009, FR-010, Rule-001, Flow-001
- **对应用户故事**: US-006, US-007, US-008, US-009, US-010

---

## 系统定位

```
┌───────────────────────────────────────────────┐
│  L5: AnnotationOverlayView / AnnotationToolbar │
│  L4: AnnotationViewModel                       │
└──────────────────────┬────────────────────────┘
                       │ ▼ 使用
┌──────────────────────▼────────────────────────┐
│        ★ MOD-05: 标注模块 ★                   │
│        AnnotationService                       │
└──────────────────────┬────────────────────────┘
                       │ ▼ 依赖
┌──────────────────────▼────────────────────────┐
│  MOD-06 AnnotationRepository（持久化）          │
│  PDFKit.PDFPage（坐标系转换）                   │
└───────────────────────────────────────────────┘
```

### 核心职责

- 管理当前激活的标注工具类型（高亮/下划线/删除线/便签/画笔/橡皮擦）
- 处理文本选择事件，转换为对应类型的标注
- 处理画布点击/拖拽事件，创建便签注释和绘制标注
- 维护当前文档的标注集合（内存中），并通过 MOD-06 持久化
- **严格遵守 Rule-001**：所有标注数据存储到数据库，不调用 PDFKit 的标注写入 API
- 驱动 AnnotationOverlayView 渲染标注视觉效果

### 边界说明

- **负责**：标注工具逻辑、标注 CRUD、标注坐标计算、Overlay 渲染数据提供
- **不负责**：标注的磁盘持久化（MOD-06 负责）、标注列表展示（MOD-07 负责）

---

## 对应 PRD

| PRD 编号 | 内容 |
|---------|------|
| FR-006 | 高亮标注，多色 |
| FR-007 | 下划线标注 |
| FR-008 | 删除线标注 |
| FR-009 | 文字注释（便签） |
| FR-010 | 自由绘制 |
| Rule-001 | 标注不修改原始 PDF |
| Flow-001 | 标注创建流程 |
| US-006~010 | 全部标注用户故事 |
| AC-006-01~06, AC-007-01~04, AC-008-01~03, AC-009-01~08, AC-010-01~06 | 全部验收条件 |

---

## 接口定义

### API-040: 创建文本标注（高亮/下划线/删除线）

**对应 PRD**: US-006, US-007, US-008

```swift
// AnnotationService
func createTextAnnotation(
    type: AnnotationType,         // .highlight / .underline / .strikethrough
    selection: PDFSelection,      // 用户选中的文本
    color: AnnotationColor,       // 颜色
    in document: PDFDocument
) throws -> AnnotationRecord
```

**行为**：
1. 从 `PDFSelection` 提取：`pageNumber`、`bounds`（坐标）、`selectedText`（原文）
2. 创建 `AnnotationRecord` 对象
3. 调用 `MOD-06.AnnotationRepository.save(record)` 持久化
4. 返回记录，AnnotationViewModel 更新内存列表

**边界**：
- `PDFSelection` 包含纯图片区域（无文本）→ 抛 `AnnotationError.noSelectableText`（AC-006 异常）

---

### API-041: 创建便签注释

**对应 PRD**: US-009, AC-009-01~08

```swift
// AnnotationService
func createNoteAnnotation(
    at point: CGPoint,         // 页面坐标（PDF 坐标系）
    pageNumber: Int,
    content: String = "",
    in document: PDFDocument
) -> AnnotationRecord
```

**行为**：
1. 创建 `type = .note` 的 `AnnotationRecord`
2. `bounds` = `CGRect(x: point.x, y: point.y, width: 200, height: 100)`（默认便签大小）
3. `content` = 初始文字（空字符串）
4. 调用 Repository 持久化

---

### API-042: 更新便签内容

**对应 PRD**: AC-009-02, AC-009-04（内容修改 + 位置拖动）

```swift
// AnnotationService
func updateAnnotation(id: UUID, content: String? = nil, bounds: CGRect? = nil)
```

---

### API-043: 删除标注

**对应 PRD**: AC-006-05, AC-009-08, AC-011-06

```swift
// AnnotationService
func deleteAnnotation(id: UUID)
```

---

### API-044: 绘制路径（自由绘制）

**对应 PRD**: US-010, AC-010-01~06

```swift
// AnnotationService
func appendDrawingStroke(
    path: [CGPoint],           // 绘制路径点序列
    color: AnnotationColor,
    lineWidth: DrawingLineWidth,  // .thin / .medium / .thick
    pageNumber: Int
) -> AnnotationRecord
```

---

### API-045: 撤销最近一次绘制

**对应 PRD**: AC-010-04

```swift
// AnnotationViewModel
func undoLastDrawing()
// 删除最近创建的 type == .drawing 的 AnnotationRecord
```

---

## 数据结构

### DATA-002: AnnotationRecord

**对应 PRD**: Entity-002

```swift
@Model
final class AnnotationRecord {
    var id: UUID                    // PK
    var documentPath: String        // FK，所属文档绝对路径
    var type: AnnotationType        // highlight/underline/strikethrough/note/drawing
    var pageNumber: Int             // 所在页码（1-indexed）
    var colorHex: String            // 颜色 hex，如 "#FFFF00"
    var content: String?            // 文字注释内容（note 类型）
    var selectedText: String?       // 被标注的原文（高亮/下划线/删除线）
    var boundsX: Double             // bounds.origin.x（PDF 坐标系）
    var boundsY: Double             // bounds.origin.y
    var boundsWidth: Double         // bounds.size.width
    var boundsHeight: Double        // bounds.size.height
    var drawingPathData: Data?      // 绘制路径序列化数据（drawing 类型）
    var createdAt: Date             // 创建时间
}

enum AnnotationType: String, Codable {
    case highlight
    case underline
    case strikethrough
    case note
    case drawing
}

enum AnnotationColor: String, CaseIterable {
    case yellow  = "#FFFF00"
    case green   = "#00FF00"
    case blue    = "#0099FF"
    case pink    = "#FF69B4"
    case orange  = "#FFA500"
    case red     = "#FF0000"  // 画笔专用
    case black   = "#000000"  // 画笔专用
}

enum DrawingLineWidth: Double {
    case thin   = 1.0
    case medium = 3.0
    case thick  = 6.0
}
```

---

## 状态机设计

### STATE-002: 标注创建状态机

**对应 PRD**: Flow-001

```
┌──────────────┐   用户选中文本（含可识别文字）   ┌────────────────┐
│    空闲       │ ─────────────────────────────▶ │  文本已选中     │
│  （无选中）   │                                 │（标注按钮可用） │
└──────────────┘                                 └───────┬────────┘
       ▲                                                 │ 用户点击标注类型
       │ 取消选中（点击空白处）                           │
       │◀───────────────────────                        ▼
       │                                         ┌────────────────┐
       │                                         │  标注已创建     │
       │ 自动回到空闲                              │（保存完成）     │
       └──────────────────────────────────────── └────────────────┘
```

**关键条件**：
- 「文本已选中」的前置条件：`PDFSelection` 包含可识别文本字符
- 纯图片区域选中 → 保持「空闲」状态，标注按钮不可用

---

## 边界条件

### BOUND-020: 文本标注边界

| 条件 | 处理 |
|-----|------|
| 选中区域无可识别文本（图片、扫描件区域） | 标注按钮保持禁用，不创建标注（AC-006 异常） |
| 选中文本跨越多页 | 仅对第一页选中区域创建标注（PDFKit 限制） |

### BOUND-021: 便签注释边界

| 条件 | 处理 |
|-----|------|
| 双击位置与已有便签重叠 | 展开已有便签，不创建新便签 |
| 便签拖动超出页面边界 | 限制在页面范围内（bounds clamp） |

### BOUND-022: 自由绘制边界

| 条件 | 处理 |
|-----|------|
| 画笔工具激活时 Cmd+Z | 删除最近一条 type=drawing 记录（AC-010-04） |
| 橡皮擦点击空白区域 | 无操作 |
| 路径点数量 < 2 | 不创建绘制记录（不构成线条） |

---

## 实现文件

| 文件路径 | 职责 |
|---------|------|
| `Features/Annotation/AnnotationService.swift` | 标注 CRUD 业务逻辑 |
| `Features/Annotation/AnnotationViewModel.swift` | 标注状态与工具选择 |
| `Features/Annotation/AnnotationOverlayView.swift` | 标注渲染叠加层（Canvas） |
| `Features/Annotation/AnnotationToolbar.swift` | 标注工具栏（颜色/粗细选择） |
| `Shared/Models/AnnotationRecord.swift` | SwiftData 模型 |
| `Shared/Models/AnnotationTypes.swift` | 枚举类型定义 |

---

## 覆盖映射

| PRD 类型 | PRD 编号 | 架构元素 | 状态 |
|---------|---------|---------|------|
| 功能需求 | FR-006 | API-040, DATA-002（type=highlight） | ✅ |
| 功能需求 | FR-007 | API-040, DATA-002（type=underline） | ✅ |
| 功能需求 | FR-008 | API-040, DATA-002（type=strikethrough） | ✅ |
| 功能需求 | FR-009 | API-041, API-042, DATA-002（type=note） | ✅ |
| 功能需求 | FR-010 | API-044, API-045, DATA-002（type=drawing） | ✅ |
| 数据实体 | Entity-002 | DATA-002 AnnotationRecord | ✅ |
| 业务规则 | Rule-001 | AnnotationService 不调用 PDFKit 写入 API | ✅ |
| 业务流程 | Flow-001 | STATE-002 | ✅ |
| 验收标准 | AC-006-01~06 | API-040, BOUND-020 | ✅ |
| 验收标准 | AC-007-01~04 | API-040 | ✅ |
| 验收标准 | AC-008-01~03 | API-040 | ✅ |
| 验收标准 | AC-009-01~08 | API-041, API-042, API-043 | ✅ |
| 验收标准 | AC-010-01~06 | API-044, API-045, BOUND-022 | ✅ |
