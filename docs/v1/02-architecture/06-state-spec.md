# 状态机规约文档

## 文档信息

- **项目名称**: PDF-Ve
- **版本**: v1.0
- **对应PRD**: docs/v1/01-prd.md
- **更新日期**: 2026-04-01

---

## 状态机清单

| 编号 | 状态机名称 | 实体/组件 | 对应PRD流程 | 状态数 | 转换数 |
|-----|-----------|---------|------------|-------|-------|
| STATE-001 | 文档打开状态机 | DocumentViewModel | Flow-002 | 4 | 5 |
| STATE-002 | 标注创建状态机 | AnnotationViewModel | Flow-001 | 3 | 4 |
| STATE-003 | 标注持久化状态机 | AnnotationRepository | Flow-002 | 3 | 3 |
| STATE-004 | 搜索状态机 | SearchViewModel | - | 4 | 6 |
| STATE-005 | 便签注释展开状态机 | AnnotationOverlayView | - | 2 | 2 |

---

## 状态机详细定义

### STATE-001: 文档打开状态机

**对应PRD**: Flow-002（文档打开阶段），US-001, Rule-002

**所属组件**: DocumentViewModel

**状态定义**：

| 状态 | 说明 | 允许操作 |
|-----|------|---------|
| `idle` | 无文档打开，显示欢迎页/最近文件列表 | 打开文件 |
| `loading` | 文件加载中（PDFDocument 初始化） | 无（等待） |
| `loaded(PDFDocument)` | 文档已加载，进入阅读模式 | 阅读、标注、搜索、关闭 |
| `error(FileError)` | 打开失败 | 显示错误、重新选择文件 |

**状态转换**：

| 编号 | 当前状态 | 触发事件 | 下一状态 | 条件 | 对应PRD |
|-----|---------|---------|---------|------|---------|
| T001 | `idle` | `openDocument(url)` 调用 | `loading` | - | AC-001-01, AC-001-02 |
| T002 | `loading` | PDFDocument 加载成功 | `loaded(doc)` | - | AC-001-04 |
| T003 | `loading` | 文件不存在 / 非PDF | `error(err)` | - | AC-001-05 |
| T004 | `loaded` | 用户关闭文档 | `idle` | 触发 Rule-002 保存阅读状态 | Rule-002 |
| T005 | `error` | 用户确认错误对话框 | `idle` | - | AC-001-05 |

**状态转换图**：

```
          openDocument()
┌────────┐ ──────────────▶ ┌─────────┐  成功   ┌──────────────┐
│  idle  │                 │ loading │ ───────▶ │ loaded(doc)  │
└────────┘                 └─────────┘          └──────┬───────┘
    ▲                           │ 失败                  │ 关闭文档
    │ 确认错误                   ▼                       │（保存状态）
    │                      ┌──────────┐                 │
    └──────────────────────│  error   │◀────────────────┘
                           └──────────┘
```

---

### STATE-002: 标注创建状态机

**对应PRD**: Flow-001, US-006~009

**所属组件**: AnnotationViewModel（与 PDFViewWrapper 协作）

**状态定义**：

| 状态 | 说明 | UI 表现 |
|-----|------|--------|
| `idle` | 无文本选中，无激活工具 | 标注工具栏按钮禁用 |
| `textSelected(PDFSelection)` | 用户选中了包含可识别文字的文本 | 工具栏标注按钮启用，右键菜单可用 |
| `annotationCreated` | 标注已创建并持久化 | 瞬时状态，立即回到 idle |

**状态转换**：

| 编号 | 当前状态 | 触发事件 | 下一状态 | 条件 | 对应PRD |
|-----|---------|---------|---------|------|---------|
| T010 | `idle` | PDFView 文本选中回调 | `textSelected(sel)` | `sel.string != nil && !sel.string!.isEmpty` | AC-006-01 |
| T011 | `idle` | 文本选中但无可识别字符 | `idle` | 图片/扫描件区域 | AC-006 异常边界 |
| T012 | `textSelected` | 点击标注工具（高亮/下划线/删除线） | `annotationCreated` | - | AC-006-01, AC-007-01, AC-008-01 |
| T013 | `textSelected` | 点击空白区域取消选中 | `idle` | - | Flow-001 |
| T014 | `annotationCreated` | 标注创建完成（自动） | `idle` | - | Flow-001 |

**特别说明**：便签注释（US-009）和自由绘制（US-010）不依赖文本选中状态，由工具模式（`activeAnnotationTool`）控制，不经过 STATE-002。

**activeAnnotationTool 状态**：

```swift
enum AnnotationTool {
    case none           // 默认，鼠标为阅读/选择模式
    case highlight(color: AnnotationColor)
    case underline(color: AnnotationColor)
    case strikethrough(color: AnnotationColor)
    case note           // 激活后双击空白区域创建便签
    case drawing(color: AnnotationColor, lineWidth: DrawingLineWidth)
    case eraser         // 点击 drawing 标注删除
}
```

---

### STATE-003: 标注持久化状态机

**对应PRD**: Flow-002, Rule-001

**所属组件**: AnnotationRepository（通过 SwiftData ModelContext）

**状态定义**：

| 状态 | 说明 |
|-----|------|
| `notLoaded` | 文档未打开，内存中无该文档的标注数据 |
| `loaded([AnnotationRecord])` | 标注已从数据库加载到内存，渲染到 Overlay |
| `persisted` | 某次写操作已完成（瞬时，立即回到 loaded） |

**状态转换**：

| 编号 | 当前状态 | 触发事件 | 下一状态 | 条件 | 对应PRD |
|-----|---------|---------|---------|------|---------|
| T020 | `notLoaded` | `fetchAll(for:)` 调用 | `loaded([])` / `loaded([records])` | 文档打开时 | Flow-002 |
| T021 | `loaded` | `save()` / `delete()` 调用 | `persisted` → `loaded` | 标注操作后立即触发 | Rule-001, < 100ms |
| T022 | `loaded` | 文档关闭 | `notLoaded` | - | Flow-002 |

**关键保证**：
- T021 是同步操作，完成时间 < 100ms（性能需求 3.1）
- `save()` 使用 SwiftData 的 `try modelContext.save()`，失败时抛出错误但不崩溃

---

### STATE-004: 搜索状态机

**对应PRD**: US-005, AC-005-01 ~ AC-005-08

**所属组件**: SearchViewModel

**状态定义**：

| 状态 | 说明 | UI 表现 |
|-----|------|--------|
| `hidden` | 搜索栏不可见 | 搜索栏隐藏 |
| `empty` | 搜索栏可见，关键词为空 | 搜索栏显示，输入框空 |
| `hasResults(count, current)` | 有搜索结果 | 搜索栏显示结果数「3/12」，匹配项高亮 |
| `noResults` | 搜索词非空但无结果 | 搜索框背景变红，提示「未找到」 |

**状态转换**：

| 编号 | 当前状态 | 触发事件 | 下一状态 | 条件 | 对应PRD |
|-----|---------|---------|---------|------|---------|
| T030 | `hidden` | Cmd+F | `empty` | - | AC-005-01 |
| T031 | `empty` | 输入关键词 + 结果 > 0 | `hasResults` | - | AC-005-02, AC-005-03 |
| T032 | `empty` | 输入关键词 + 结果 = 0 | `noResults` | - | AC-005-07 |
| T033 | `hasResults` | Enter / Cmd+G | `hasResults(next)` | 循环跳转 | AC-005-04 |
| T034 | `hasResults` | Shift+Enter / Cmd+Shift+G | `hasResults(prev)` | 循环跳转 | AC-005-05 |
| T035 | `hasResults` / `noResults` / `empty` | Esc | `hidden` | 清除高亮 | AC-005-08 |

**状态转换图**：

```
                 Cmd+F
┌────────┐ ──────────────▶ ┌───────┐  输入词+有结果  ┌────────────┐
│ hidden │                 │ empty │ ──────────────▶ │ hasResults │
└────────┘                 └───────┘                └─────┬──────┘
    ▲                          │ 输入词+无结果              │ Enter/Shift+Enter
    │                          ▼                          │（循环导航）
    │                     ┌──────────┐                    │
    └──── Esc ────────────│ noResults│◀───────────────────┘
                          └──────────┘      Esc
```

---

### STATE-005: 便签注释展开状态机

**对应PRD**: US-009, AC-009-05, AC-009-06

**所属组件**: AnnotationOverlayView（每个 note 类型标注独立实例）

**状态定义**：

| 状态 | 说明 | UI 表现 |
|-----|------|--------|
| `collapsed` | 折叠为图标 | 显示小图标（便签样式） |
| `expanded` | 展开显示内容 | 显示便签文字框，可编辑 |

**状态转换**：

| 编号 | 当前状态 | 触发事件 | 下一状态 | 对应PRD |
|-----|---------|---------|---------|---------|
| T040 | `expanded` | 点击便签外部区域 | `collapsed` | AC-009-05 |
| T041 | `collapsed` | 点击便签图标 | `expanded` | AC-009-06 |

> 注：新创建的便签初始状态为 `expanded`（用户双击创建后立即可编辑）
