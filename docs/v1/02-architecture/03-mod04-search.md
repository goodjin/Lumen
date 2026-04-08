# MOD-04: 全文搜索模块

## 文档信息

- **模块编号**: MOD-04
- **版本**: v1.0
- **更新日期**: 2026-04-01
- **对应PRD**: FR-005
- **对应用户故事**: US-005

---

## 系统定位

```
┌─────────────────────────────────────┐
│  L5: SearchBarView                  │
│  L4: SearchViewModel                │
└────────────────┬────────────────────┘
                 │ ▼ 使用
┌────────────────▼────────────────────┐
│     ★ MOD-04: 全文搜索模块 ★        │
│     SearchService                   │
└────────────────┬────────────────────┘
                 │ ▼ 依赖
┌────────────────▼────────────────────┐
│  PDFKit.PDFDocument.findString()    │
│  MOD-02 ReaderViewModel（跳转）      │
└─────────────────────────────────────┘
```

### 核心职责

- 调用 `PDFDocument.findString(_:withOptions:)` 执行全文搜索
- 维护搜索结果集合和当前匹配索引
- 驱动 PDFView 高亮显示匹配项，跳转到指定匹配位置
- 管理搜索栏的显示/隐藏状态

---

## 对应 PRD

| PRD 编号 | 内容 |
|---------|------|
| FR-005 | 全文搜索，关键词搜索并高亮 |
| US-005 | 在 PDF 中搜索关键词 |
| AC-005-01~08 | 全部验收条件 |

---

## 接口定义

### API-030: 执行搜索

**对应 PRD**: AC-005-01 ~ AC-005-07

```swift
// SearchService
func search(keyword: String, in document: PDFDocument, caseSensitive: Bool = false) -> [PDFSelection]
```

**行为**：
1. `keyword` 为空时返回空数组
2. 调用 `PDFDocument.findString(keyword, withOptions: options)`
   - `caseSensitive = false` → options 包含 `.caseInsensitive`
3. 返回所有匹配的 `PDFSelection` 数组

**边界**：
- `keyword` 超过 100 字符 → 截断到 100 字符（AC-005 输入边界）
- PDF 无可搜索文本（纯图片扫描件）→ PDFKit 返回空数组，SearchViewModel 显示「此文档不包含可搜索文本」

---

### API-031: 导航到下一个匹配项

**对应 PRD**: AC-005-04

```swift
// SearchViewModel
func nextMatch()
// currentIndex = (currentIndex + 1) % results.count
// 调用 PDFView.setCurrentSelection(_:animate:)，再 go(to:)
```

### API-032: 导航到上一个匹配项

**对应 PRD**: AC-005-05

```swift
// SearchViewModel
func previousMatch()
// currentIndex = (currentIndex - 1 + results.count) % results.count
```

### API-033: 关闭搜索

**对应 PRD**: AC-005-08

```swift
// SearchViewModel
func dismissSearch()
// isSearchBarVisible = false
// PDFView.clearSelection()
// results = []
```

---

## 数据结构

```swift
struct SearchState {
    var keyword: String = ""
    var results: [PDFSelection] = []
    var currentIndex: Int = 0
    var isSearchBarVisible: Bool = false
    var caseSensitive: Bool = false
    var hasNoResults: Bool { !keyword.isEmpty && results.isEmpty }

    // 用于工具栏显示「3/12」格式（AC-005-03）
    var resultSummary: String {
        guard !results.isEmpty else { return "" }
        return "\(currentIndex + 1)/\(results.count)"
    }
}
```

---

## 边界条件

| 条件 | 处理 |
|-----|------|
| 搜索词为空 | 清空结果，不执行搜索 |
| 无匹配结果 | `hasNoResults = true`，SearchBarView 背景变红（AC-005-07） |
| PDF 无可搜索文本 | 显示特殊提示「此文档不包含可搜索文本」（AC-005 异常） |
| 搜索词长度 > 100 | 截断到 100 字符 |
| Esc 键 | 调用 `dismissSearch()`（AC-005-08） |

---

## 实现文件

| 文件路径 | 职责 |
|---------|------|
| `Features/Search/SearchBarView.swift` | 搜索栏视图 |
| `Features/Search/SearchViewModel.swift` | 搜索状态管理 |
| `Features/Search/SearchService.swift` | PDFKit 搜索封装 |

---

## 覆盖映射

| PRD 类型 | PRD 编号 | 架构元素 | 状态 |
|---------|---------|---------|------|
| 功能需求 | FR-005 | MOD-04, SearchService | ✅ |
| 用户故事 | US-005 | API-030~033 | ✅ |
| 验收标准 | AC-005-01~08 | 全部边界条件覆盖 | ✅ |
