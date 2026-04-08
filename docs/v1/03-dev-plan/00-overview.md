# 开发计划总览

## 文档信息

- **项目名称**: PDF-Ve（PDF Viewer Enhanced）
- **版本**: v1.0
- **对应架构**: docs/v1/02-architecture/
- **创建日期**: 2026-04-01

---

## 1. 项目概述

PDF-Ve 是一款 macOS 原生 PDF 阅读器，使用 Swift + SwiftUI + PDFKit + SwiftData 实现。无前后端分离，是纯本地单机应用。

**技术栈**：
- 语言：Swift 5.9+
- UI 框架：SwiftUI + AppKit（NSViewRepresentable）
- PDF 引擎：PDFKit（Apple 系统框架）
- 数据持久化：SwiftData（macOS 14+）
- 构建工具：Xcode 15+ / Swift Package Manager
- 最低系统：macOS 13 Ventura
- 架构：Universal Binary（arm64 + x86_64）

---

## 2. 模块开发批次

### 第1批：基础设施（无依赖）

| 计划编号 | 模块 | 开发计划文档 | 任务数 | 优先级 |
|---------|------|------------|-------|-------|
| P-01 | 项目骨架 + 数据层 | 01-foundation.md | 6 | P0 |
| P-02 | MOD-01 文件管理 | 02-mod01-document.md | 5 | P0 |

### 第2批：核心阅读（依赖第1批）

| 计划编号 | 模块 | 开发计划文档 | 任务数 | 优先级 |
|---------|------|------------|-------|-------|
| P-03 | MOD-02 PDF渲染 | 03-mod02-reader.md | 5 | P0 |
| P-04 | MOD-03 目录导航 | 04-mod03-outline.md | 3 | P0 |
| P-05 | MOD-04 全文搜索 | 05-mod04-search.md | 3 | P0 |

### 第3批：标注系统（依赖第2批）

| 计划编号 | 模块 | 开发计划文档 | 任务数 | 优先级 |
|---------|------|------------|-------|-------|
| P-06 | MOD-05 标注工具 | 06-mod05-annotation.md | 7 | P0 |
| P-07 | MOD-06 标注存储 | 07-mod06-storage.md | 4 | P0 |

### 第4批：侧栏与辅助功能（依赖第3批）

| 计划编号 | 模块 | 开发计划文档 | 任务数 | 优先级 |
|---------|------|------------|-------|-------|
| P-08 | MOD-07 侧栏 | 08-mod07-sidebar.md | 6 | P1 |

**总计**：8 份开发计划，39 个原子化任务

---

## 3. 开发顺序

```
第1批
├── P-01: 项目骨架 + SwiftData 数据层
└── P-02: 文件管理（FileService + DocumentViewModel）

第2批（依赖P-01, P-02）
├── P-03: PDF渲染（PDFViewWrapper + ReaderViewModel）
├── P-04: 目录导航（OutlineView）
└── P-05: 全文搜索（SearchService）

第3批（依赖P-03）
├── P-06: 标注工具（AnnotationService + OverlayView）
└── P-07: 标注存储（Repository + ExportService）

第4批（依赖P-06, P-07）
└── P-08: 侧栏（AnnotationList + Bookmark + Thumbnail）
```

---

## 4. 目录结构规划

开发完成后的 Xcode 项目结构：

```
PDF-Ve/
├── App/
│   ├── PDF_VeApp.swift
│   └── AppDelegate.swift
├── Features/
│   ├── Document/
│   │   ├── FileService.swift
│   │   ├── DocumentViewModel.swift
│   │   └── RecentFilesView.swift
│   ├── Reader/
│   │   ├── PDFReaderView.swift
│   │   ├── PDFViewWrapper.swift
│   │   ├── ReaderViewModel.swift
│   │   └── ToolbarView.swift
│   ├── Outline/
│   │   ├── OutlineView.swift
│   │   └── OutlineViewModel.swift
│   ├── Search/
│   │   ├── SearchBarView.swift
│   │   ├── SearchViewModel.swift
│   │   └── SearchService.swift
│   ├── Annotation/
│   │   ├── AnnotationService.swift
│   │   ├── AnnotationViewModel.swift
│   │   ├── AnnotationOverlayView.swift
│   │   └── AnnotationToolbar.swift
│   ├── AnnotationStorage/
│   │   └── ExportService.swift
│   └── Sidebar/
│       ├── SidebarView.swift
│       ├── AnnotationListView.swift
│       ├── BookmarkListView.swift
│       ├── ThumbnailGridView.swift
│       ├── SidebarViewModel.swift
│       ├── BookmarkService.swift
│       └── ThumbnailProvider.swift
├── Shared/
│   ├── Models/
│   │   ├── DocumentRecord.swift
│   │   ├── AnnotationRecord.swift
│   │   ├── BookmarkRecord.swift
│   │   ├── AnnotationTypes.swift
│   │   ├── OutlineItem.swift
│   │   └── FileError.swift
│   └── Extensions/
│       └── NSColor+Hex.swift
└── Infrastructure/
    └── Persistence/
        ├── PersistenceController.swift
        ├── DocumentRepository.swift
        ├── AnnotationRepository.swift
        └── BookmarkRepository.swift
```

---

## 5. 开发规范

### 5.1 代码规范
- Swift 官方风格指南（SwiftLint 可选）
- 文件内类/结构体命名与文件名一致
- `@MainActor` 修饰所有 ViewModel
- 异步操作使用 `async/await`，不使用 Combine

### 5.2 提交规范（Conventional Commits）
```
feat(mod-01): add file open dialog
fix(mod-05): annotation overlay not refreshing
test(mod-06): add annotation repository unit tests
```

### 5.3 任务约束
- **代码变更**：≤ 200 行
- **涉及文件**：≤ 5 个
- **执行时间**：≤ 30 分钟

### 5.4 项目特定验证规范

#### SwiftUI macOS 布局验证清单

**HSplitView 约束验证**:
- [ ] 子视图有明确的 `minWidth` / `idealWidth` / `maxWidth` 约束
- [ ] 侧栏宽度符合 UI-Layout-003 规范（240pt）
- [ ] 主内容区能正确撑满剩余空间

**工具栏高度验证**:
- [ ] 自定义工具栏高度 ≤ UI-Layout-001 规范（44pt）
- [ ] 已考虑系统工具栏高度（使用 `.windowToolbarStyle(.unified)`）
- [ ] 总工具栏高度 = 系统工具栏 + 自定义工具栏 ≤ 设计高度

**点击区域验证**:
- [ ] 可点击元素使用 `.contentShape(Rectangle())` 确保点击区域
- [ ] 列表项、缩略图、按钮都有明确的点击响应

**macOS 系统行为验证**:
- [ ] 全屏模式下侧栏自动隐藏行为正确
- [ ] 窗口大小变化时布局自适应正确
- [ ] 系统工具栏与自定义工具栏不重复

#### 验收标准三级验证格式

所有 View 层任务必须使用以下验收标准格式：

```markdown
**验收标准**:
- [ ] **数据展示验证**: [静态渲染正确、空状态处理等]
- [ ] **布局验证**: [尺寸符合 UI-Layout-XXX、不挤占核心内容区等]
- [ ] **交互验证**: [事件触发验证、状态反馈验证、数据流转验证等]
```

---

## 6. 覆盖映射

| 架构模块 | 开发计划 | 状态 |
|---------|---------|------|
| MOD-01 文件管理 | P-02 | ✅ |
| MOD-02 PDF渲染 | P-03 | ✅ |
| MOD-03 目录导航 | P-04 | ✅ |
| MOD-04 全文搜索 | P-05 | ✅ |
| MOD-05 标注工具 | P-06 | ✅ |
| MOD-06 标注存储 | P-07 | ✅ |
| MOD-07 侧栏 | P-08 | ✅ |
| 数据层基础设施 | P-01 | ✅ |
