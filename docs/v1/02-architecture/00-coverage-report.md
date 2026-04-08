# PRD-架构覆盖报告

## 文档信息

- **项目名称**: PDF-Ve
- **版本**: v1.0
- **更新日期**: 2026-04-01

---

## 覆盖统计

| 类型 | PRD总数 | 已覆盖 | 未覆盖 | 覆盖率 |
|-----|--------|-------|-------|-------|
| 功能需求 | 16 | 16 | 0 | **100%** |
| 用户故事 | 16 | 16 | 0 | **100%** |
| 数据实体 | 3 | 3 | 0 | **100%** |
| 业务流程 | 2 | 2 | 0 | **100%** |
| 业务规则 | 4 | 4 | 0 | **100%** |
| 验收标准 | 67 | 67 | 0 | **100%** |
| 接口定义 | 31 | 31 | 0 | **100%** |
| View层接口 | 5 | 5 | 0 | **100%** |
| 边界条件 | 15 | 15 | 0 | **100%** |
| 状态机 | 5 | 5 | 0 | **100%** |
| UI布局约束 | 4 | 4 | 0 | **100%** |
| 时序设计 | 1 | 1 | 0 | **100%** |

---

## 详细覆盖清单

### 功能需求覆盖

| PRD编号 | 功能名称 | 优先级 | 架构模块 | 接口规约 | 数据规约 | 状态 |
|---------|---------|-------|---------|---------|---------|------|
| FR-001 | PDF文件打开 | P0 | MOD-01 | API-001, API-004 | DATA-001 | ✅ |
| FR-002 | 页面浏览与导航 | P0 | MOD-02 | API-010 | ReaderState | ✅ |
| FR-003 | 缩放 | P0 | MOD-02 | API-011 | ReaderState | ✅ |
| FR-004 | 目录导航 | P0 | MOD-03 | API-020, API-021 | OutlineItem | ✅ |
| FR-005 | 全文搜索 | P0 | MOD-04 | API-030~033 | SearchState | ✅ |
| FR-006 | 高亮标注 | P0 | MOD-05 | API-040 | DATA-002 | ✅ |
| FR-007 | 下划线标注 | P0 | MOD-05 | API-040 | DATA-002 | ✅ |
| FR-008 | 删除线标注 | P1 | MOD-05 | API-040 | DATA-002 | ✅ |
| FR-009 | 文字注释 | P0 | MOD-05 | API-041, API-042 | DATA-002 | ✅ |
| FR-010 | 自由绘制 | P1 | MOD-05 | API-044, API-045 | DATA-002 | ✅ |
| FR-011 | 标注列表侧栏 | P0 | MOD-07 | API-060~062 | - | ✅ |
| FR-012 | 书签 | P1 | MOD-07 | API-063~066 | DATA-003 | ✅ |
| FR-013 | 页面缩略图 | P1 | MOD-07 | API-067 | - | ✅ |
| FR-014 | 全屏模式 | P1 | MOD-02 | API-012 | ReaderState | ✅ |
| FR-015 | 最近文件 | P1 | MOD-01 | API-003, API-004 | DATA-001 | ✅ |
| FR-016 | 标注导出 | P2 | MOD-06 | API-053 | - | ✅ |

### 用户故事覆盖

| PRD编号 | 用户故事摘要 | 接口规约 | 状态机 | 边界条件 | 状态 |
|---------|------------|---------|-------|---------|------|
| US-001 | 打开PDF文件 | API-001 | STATE-001 | BOUND-001 | ✅ |
| US-002 | 浏览PDF页面 | API-010 | - | BOUND-010 | ✅ |
| US-003 | 缩放页面 | API-011 | - | BOUND-011 | ✅ |
| US-004 | 使用目录导航 | API-020, API-021 | - | MOD-03边界 | ✅ |
| US-005 | 全文搜索 | API-030~033 | STATE-004 | BOUND-050, BOUND-051 | ✅ |
| US-006 | 高亮标注 | API-040, API-043 | STATE-002 | BOUND-020 | ✅ |
| US-007 | 下划线标注 | API-040, API-043 | STATE-002 | BOUND-020 | ✅ |
| US-008 | 删除线标注 | API-040, API-043 | STATE-002 | BOUND-020 | ✅ |
| US-009 | 文字注释 | API-041, API-042, API-043 | STATE-005 | BOUND-021 | ✅ |
| US-010 | 自由绘制 | API-044, API-045 | - | BOUND-022 | ✅ |
| US-011 | 查看标注列表 | API-060, API-061, API-062 | - | BOUND-040 | ✅ |
| US-012 | 书签管理 | API-063~066 | - | BOUND-041 | ✅ |
| US-013 | 页面缩略图 | API-067 | - | BOUND-042 | ✅ |
| US-014 | 全屏阅读 | API-012 | STATE-001 | - | ✅ |
| US-015 | 最近文件 | API-003, API-004 | STATE-001 | BOUND-002, BOUND-003 | ✅ |
| US-016 | 导出标注 | API-053 | - | BOUND-031 | ✅ |

### 数据实体覆盖

| PRD编号 | 实体名称 | 数据结构规约 | 索引设计 | 状态 |
|---------|---------|------------|---------|------|
| Entity-001 | 文档（Document） | DATA-001 DocumentRecord | idx_doc_filePath, idx_doc_lastOpened | ✅ |
| Entity-002 | 标注（Annotation） | DATA-002 AnnotationRecord | idx_ann_docPath, idx_ann_docPage | ✅ |
| Entity-003 | 书签（Bookmark） | DATA-003 BookmarkRecord | idx_bm_docPath, idx_bm_docPage | ✅ |

### 业务流程覆盖

| PRD编号 | 流程名称 | 状态机 | 接口 | 状态 |
|---------|---------|-------|------|------|
| Flow-001 | 标注创建流程 | STATE-002 | API-040~044 | ✅ |
| Flow-002 | 标注持久化流程 | STATE-001, STATE-003 | API-050, API-051 | ✅ |

### 业务规则覆盖

| PRD编号 | 规则名称 | 实现位置 | 状态 |
|---------|---------|---------|------|
| Rule-001 | 标注不修改原始PDF | AnnotationService（不调用PDFKit写入API）+ MOD-06存储策略 | ✅ |
| Rule-002 | 记忆上次阅读位置 | API-002, STATE-001 T004, DocumentRepository | ✅ |
| Rule-003 | 文件路径失效处理 | API-004, BOUND-003 | ✅ |
| Rule-004 | 最近文件数量上限20条 | BOUND-002, DocumentRepository.recordOpen() | ✅ |

### 验收标准覆盖（按功能分组）

**FR-001 文件打开（AC-001-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-001-01 | 菜单「文件>打开」 | NSOpenPanel in FileService | ✅ |
| AC-001-02 | 拖拽打开 | onDrop modifier in MainWindowView | ✅ |
| AC-001-03 | 系统文件关联 | Info.plist CFBundleDocumentTypes | ✅ |
| AC-001-04 | 3秒内显示首页 | async加载 + PDFKit流式渲染 | ✅ |
| AC-001-05 | 无效PDF显示错误 | BOUND-001, FileError处理 | ✅ |

**FR-002 页面浏览（AC-002-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-002-01 | 滚轮/触控板翻页 | PDFView内置支持 | ✅ |
| AC-002-02 | 键盘翻页 | PDFView keyDown处理 | ✅ |
| AC-002-03 | 工具栏显示页码 | ReaderViewModel.currentPage绑定 | ✅ |
| AC-002-04 | 页码输入跳转 | API-010 + BOUND-010 | ✅ |
| AC-002-05 | 60fps流畅滚动 | PDFKit硬件加速渲染 | ✅ |

**FR-003 缩放（AC-003-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-003-01 | Cmd+加减号缩放 | KeyboardShortcut + API-011 | ✅ |
| AC-003-02 | Cmd+0还原100% | setZoomMode(.actual) | ✅ |
| AC-003-03 | Cmd+1适合宽度 | setZoomMode(.fitWidth) | ✅ |
| AC-003-04 | Cmd+2适合页面 | setZoomMode(.fitPage) | ✅ |
| AC-003-05 | 触控板捏合缩放 | PDFView magnifyWithEvent | ✅ |
| AC-003-06 | 缩放范围10%-500% | BOUND-011 clamp | ✅ |
| AC-003-07 | 工具栏显示缩放比例 | ReaderViewModel.zoomLevel绑定 | ✅ |

**FR-004 目录导航（AC-004-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-004-01 | 侧栏显示目录树 | OutlineView + API-020 | ✅ |
| AC-004-02 | 点击跳转 | API-021 | ✅ |
| AC-004-03 | 支持5级层级 | OutlineItem.depth限制 | ✅ |
| AC-004-04 | 折叠/展开 | OutlineItem.isExpanded | ✅ |
| AC-004-05 | 无目录提示 | OutlineView空状态 | ✅ |
| AC-004-06 | Cmd+T侧栏显隐 | SidebarViewModel.isVisible | ✅ |

**FR-005 全文搜索（AC-005-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-005-01 | Cmd+F打开 | KeyboardShortcut | ✅ |
| AC-005-02 | 匹配项高亮 | PDFView.currentSelection | ✅ |
| AC-005-03 | 显示结果数X/Y | SearchState.resultSummary | ✅ |
| AC-005-04 | Enter/Cmd+G下一个 | API-031 | ✅ |
| AC-005-05 | Shift+Enter上一个 | API-032 | ✅ |
| AC-005-06 | 默认不区分大小写 | API-030 caseSensitive=false | ✅ |
| AC-005-07 | 无匹配搜索框变红 | SearchState.hasNoResults → 红色背景 | ✅ |
| AC-005-08 | Esc关闭搜索 | API-033 | ✅ |

**FR-006~010 标注（AC-006-xx ~ AC-010-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-006-01 | 选中文本触发高亮 | STATE-002, textSelected状态 | ✅ |
| AC-006-02 | 5种高亮颜色 | AnnotationColor枚举 | ✅ |
| AC-006-03 | 半透明高亮背景 | AnnotationOverlayView Canvas渲染 | ✅ |
| AC-006-04 | 高亮持久化 | API-050 | ✅ |
| AC-006-05 | 右键删除高亮 | contextMenu + API-043 | ✅ |
| AC-006-06 | 双击高亮添加注释 | onTapGesture(count:2) + API-041 | ✅ |
| AC-007-01~04 | 下划线标注 | API-040(type:.underline) + API-050 | ✅ |
| AC-008-01~03 | 删除线标注 | API-040(type:.strikethrough) + API-050 | ✅ |
| AC-009-01~08 | 便签注释全部 | API-041, API-042, API-043, STATE-005 | ✅ |
| AC-010-01~06 | 自由绘制全部 | API-044, API-045, BOUND-022 | ✅ |

**FR-011 标注列表（AC-011-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-011-01 | 侧栏标注标签 | AnnotationListView | ✅ |
| AC-011-02 | 按页码升序 | API-051排序保证 | ✅ |
| AC-011-03 | 显示类型/页码/摘要 | AnnotationListRow视图 | ✅ |
| AC-011-04 | 点击跳转 | API-062 | ✅ |
| AC-011-05 | 按类型筛选 | API-061 | ✅ |
| AC-011-06 | 列表中删除 | contextMenu + API-043 | ✅ |

**FR-012 书签（AC-012-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-012-01 | Cmd+B切换书签 | API-063 toggleBookmark | ✅ |
| AC-012-02 | 侧栏书签标签 | BookmarkListView | ✅ |
| AC-012-03 | 显示名称和页码 | BookmarkListRow | ✅ |
| AC-012-04 | 双击重命名 | onTapGesture(count:2) + API-064 | ✅ |
| AC-012-05 | 点击跳转 | API-065 | ✅ |
| AC-012-06 | 书签持久化 | BookmarkRepository.save() | ✅ |
| AC-012-07 | 右键删除 | contextMenu + API-066 | ✅ |

**FR-013 缩略图（AC-013-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-013-01 | 缩略图网格 | ThumbnailGridView LazyVGrid | ✅ |
| AC-013-02 | 显示页码 | ThumbnailCell页码标签 | ✅ |
| AC-013-03 | 当前页高亮边框 | ReaderViewModel.currentPage比较 | ✅ |
| AC-013-04 | 点击跳转 | API-010 | ✅ |
| AC-013-05 | 按需加载 | LazyVGrid + task {} + BOUND-042 | ✅ |

**FR-014 全屏（AC-014-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-014-01 | Cmd+Ctrl+F全屏 | API-012 | ✅ |
| AC-014-02 | 工具栏/侧栏可隐藏 | macOS全屏自动行为 + hidesSidebarOnFullscreen | ✅ |
| AC-014-03 | 全屏支持所有操作 | 无限制，全屏不禁用任何功能 | ✅ |
| AC-014-04 | 退出全屏 | API-012 toggleFullscreen | ✅ |

**FR-015 最近文件（AC-015-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-015-01 | 启动显示最近文件 | RecentFilesView, API-003 | ✅ |
| AC-015-02 | 菜单「文件>最近打开」 | NSRecentDocumentsMenu | ✅ |
| AC-015-03 | 显示文件名/路径/时间 | RecentFileRow | ✅ |
| AC-015-04 | 点击打开 | API-004 | ✅ |
| AC-015-05 | 不存在时提示并移除 | BOUND-003 | ✅ |

**FR-016 标注导出（AC-016-xx）**

| AC编号 | 验收标准 | 实现 | 状态 |
|-------|---------|------|------|
| AC-016-01 | 菜单触发导出 | File菜单 + ExportService | ✅ |
| AC-016-02 | 导出.txt含页码/类型/内容 | API-053输出格式 | ✅ |
| AC-016-03 | 按页码升序 | API-053排序保证 | ✅ |
| AC-016-04 | 导出成功提示 | NSSavePanel + Toast通知 | ✅ |

---

## 未覆盖项

**[无未覆盖项]**

✅ 所有 PRD 需求已 100% 覆盖

---

## 变更历史

| 版本 | 日期 | 变更内容 |
|-----|------|---------|
| 1.0 | 2026-04-01 | 初始版本，基于 PRD v1.0 生成 |
| 1.1 | 2026-04-06 | 补充 View 层交互接口、级联影响分析、UI 布局约束、时序设计（基于优化后的 architecture-designer 技能） |
