# 整体架构设计

## 文档信息

- **项目名称**: PDF-Ve（PDF Viewer Enhanced）
- **版本**: v1.0
- **对应PRD**: docs/v1/01-prd.md
- **更新日期**: 2026-04-01

---

## 1. 系统定位

### 1.1 系统概述

PDF-Ve 是一款 macOS 原生 PDF 阅读器，定位为**个人使用的轻量高性能阅读与标注工具**。系统核心目标：

- **极速启动**：冷启动 < 1 秒
- **流畅渲染**：滚动 60fps，100MB 文件 < 3 秒显示首页
- **完善标注**：支持高亮、下划线、删除线、便签注释、自由绘制五种标注
- **标注独立**：标注数据不修改原始 PDF，独立存储（Rule-001）
- **原生体验**：SwiftUI + AppKit，符合 macOS Human Interface Guidelines

### 1.2 核心功能模块

```
┌─────────────────────────────────────────────────────────────────┐
│                         PDF-Ve 应用                              │
│                                                                  │
│  ┌──────────────┐  ┌─────────────────────────────────────────┐  │
│  │   侧栏面板    │  │              主阅读视图                   │  │
│  │              │  │                                          │  │
│  │ • 目录导航   │  │  ┌──────────────────────────────────┐   │  │
│  │ • 标注列表   │  │  │         PDF 页面渲染区             │   │  │
│  │ • 书签列表   │  │  │    (PDFKit / PDFView)            │   │  │
│  │ • 页面缩略图 │  │  └──────────────────────────────────┘   │  │
│  └──────────────┘  │                                          │  │
│                    │  ┌──────────────────────────────────┐   │  │
│                    │  │         搜索栏（收起/展开）          │   │  │
│                    │  └──────────────────────────────────┘   │  │
│                    └─────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                       工具栏                              │   │
│  │  [打开] [上页/下页] [页码输入] [缩放] [标注工具] [全屏]    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 功能模块与 PRD 对应

| 模块 | 编号 | 对应 PRD 功能 |
|-----|------|-------------|
| 文件管理模块 | MOD-01 | FR-001, FR-015 |
| PDF 渲染模块 | MOD-02 | FR-002, FR-003, FR-014 |
| 目录导航模块 | MOD-03 | FR-004 |
| 搜索模块 | MOD-04 | FR-005 |
| 标注模块 | MOD-05 | FR-006, FR-007, FR-008, FR-009, FR-010 |
| 标注存储模块 | MOD-06 | FR-006~FR-010（持久化）, FR-016 |
| 侧栏模块 | MOD-07 | FR-011, FR-012, FR-013 |

---

## 2. 技术选型

| 层次 | 技术栈 | 选型理由 |
|-----|-------|---------|
| UI 框架 | SwiftUI + AppKit | macOS 原生，符合 HIG，Deep Dark Mode 支持，性能最优 |
| PDF 渲染 | PDFKit（Apple 官方框架） | 系统级 PDF 渲染，零额外依赖，支持文本选择、搜索、标注渲染 |
| 数据持久化 | SwiftData（macOS 14+）/ CoreData（兼容 13） | 原生本地持久化，零网络依赖，轻量 |
| 项目构建 | Swift Package Manager (SPM) | 原生构建工具，无需第三方 |
| 最低系统版本 | macOS 13 Ventura | PRD 要求（3.2 兼容性需求） |
| 架构 | Universal Binary（arm64 + x86_64） | PRD 要求（3.2 兼容性需求） |
| 应用架构模式 | MVVM + Coordinator | 适合 SwiftUI，职责清晰，易于测试 |

### PDFKit 能力说明

Apple 的 PDFKit 框架直接提供：
- `PDFDocument` - PDF 文件加载与解析
- `PDFPage` - 单页渲染
- `PDFView` - 可滚动的 PDF 视图（支持缩放、页面导航）
- `PDFSelection` - 文本选择
- `PDFAnnotation` - 标注渲染（高亮、下划线、删除线、便签）
- `PDFOutline` - 目录树

> **重要架构决策**：PDFKit 的 `PDFAnnotation` 写入会修改 PDF 文件本身。为遵守 Rule-001（标注不修改原始 PDF），本项目**不使用 PDFKit 的标注写入 API**，而是：
> 1. 标注数据存储在 SwiftData/CoreData 数据库中
> 2. 在 PDF 页面上叠加自定义渲染层（Overlay View）来绘制标注视觉效果

---

## 3. 分层架构

```
┌─────────────────────────────────────────────────────┐
│                  L5: 视图层（SwiftUI）                │
│   MainWindowView / SidebarView / PDFReaderView       │
│   ToolbarView / SearchBarView / AnnotationOverlay    │
└────────────────────────┬────────────────────────────┘
                         │ 数据绑定 / 事件
┌────────────────────────▼────────────────────────────┐
│              L4: ViewModel 层（MVVM）                 │
│   DocumentViewModel / AnnotationViewModel            │
│   SidebarViewModel / SearchViewModel                 │
└────────────────────────┬────────────────────────────┘
                         │ 调用
┌────────────────────────▼────────────────────────────┐
│               L3: 业务逻辑层（Service）               │
│   FileService / AnnotationService / BookmarkService  │
│   SearchService / ExportService                      │
└────────────────────────┬────────────────────────────┘
                         │ 调用
┌────────────────────────▼────────────────────────────┐
│               L2: 数据访问层（Repository）             │
│   DocumentRepository / AnnotationRepository          │
│   BookmarkRepository                                 │
└────────────────────────┬────────────────────────────┘
                         │ 访问
┌────────────────────────▼────────────────────────────┐
│              L1: 基础设施层                           │
│   SwiftData/CoreData Store / PDFKit / FileManager    │
└─────────────────────────────────────────────────────┘
```

---

## 4. 目录结构规划

```
PDF-Ve/
├── App/
│   ├── PDF_VeApp.swift          # 应用入口
│   └── AppDelegate.swift        # AppKit 集成
├── Features/
│   ├── Document/                # MOD-01 文件管理
│   ├── Reader/                  # MOD-02 PDF渲染
│   ├── Outline/                 # MOD-03 目录导航
│   ├── Search/                  # MOD-04 全文搜索
│   ├── Annotation/              # MOD-05 标注工具
│   ├── AnnotationStorage/       # MOD-06 标注存储
│   └── Sidebar/                 # MOD-07 侧栏
├── Shared/
│   ├── Models/                  # 数据模型
│   ├── ViewModels/              # 共享 ViewModel
│   └── Extensions/              # Swift 扩展
├── Infrastructure/
│   ├── Persistence/             # SwiftData/CoreData
│   └── FileSystem/              # 文件系统操作
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

---

## 5. 覆盖映射

| PRD 功能 | 覆盖模块 | 状态 |
|---------|---------|------|
| FR-001 PDF文件打开 | MOD-01 | ✅ |
| FR-002 页面浏览与导航 | MOD-02 | ✅ |
| FR-003 缩放 | MOD-02 | ✅ |
| FR-004 目录导航 | MOD-03 | ✅ |
| FR-005 全文搜索 | MOD-04 | ✅ |
| FR-006 高亮标注 | MOD-05 | ✅ |
| FR-007 下划线标注 | MOD-05 | ✅ |
| FR-008 删除线标注 | MOD-05 | ✅ |
| FR-009 文字注释 | MOD-05 | ✅ |
| FR-010 自由绘制 | MOD-05 | ✅ |
| FR-011 标注列表侧栏 | MOD-07 | ✅ |
| FR-012 书签 | MOD-07 | ✅ |
| FR-013 页面缩略图 | MOD-07 | ✅ |
| FR-014 全屏模式 | MOD-02 | ✅ |
| FR-015 最近文件 | MOD-01 | ✅ |
| FR-016 标注导出 | MOD-06 | ✅ |
