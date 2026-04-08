# P-05: MOD-04 全文搜索模块

## 文档信息

- **计划编号**: P-05
- **批次**: 第2批
- **对应架构**: docs/v1/02-architecture/03-mod04-search.md
- **优先级**: P0
- **前置依赖**: P-03

---

## 模块职责

调用 PDFKit 全文搜索，管理搜索结果导航，搜索栏显示/隐藏。对应 PRD: FR-005, US-005。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-05-01 | SearchService + SearchViewModel | 2 | ~120 | P-03 |
| T-05-02 | SearchBarView | 1 | ~100 | T-05-01 |
| T-05-03 | 集成到 MainWindowView | 1 | ~30 | T-05-02 |

---

## 详细任务定义

### T-05-01: SearchService + SearchViewModel

**输出文件**:
- `PDF-Ve/Features/Search/SearchService.swift`
- `PDF-Ve/Features/Search/SearchViewModel.swift`

**实现要求**:

```swift
// SearchService.swift
import PDFKit

class SearchService {
    // API-030
    func search(keyword: String, in document: PDFDocument, caseSensitive: Bool = false) -> [PDFSelection] {
        let truncated = String(keyword.prefix(100))  // BOUND-050
        guard !truncated.isEmpty else { return [] }
        var options: NSString.CompareOptions = []
        if !caseSensitive { options.insert(.caseInsensitive) }
        return document.findString(truncated, withOptions: options)
    }

    func isSearchable(_ document: PDFDocument) -> Bool {
        // 检查 PDF 是否含有可搜索文本（BOUND-051）
        return document.string != nil
    }
}

// SearchViewModel.swift
import PDFKit
import SwiftUI

@MainActor
@Observable
class SearchViewModel {
    private let service = SearchService()

    var keyword: String = ""
    var results: [PDFSelection] = []
    var currentIndex: Int = 0
    var isSearchBarVisible: Bool = false
    var caseSensitive: Bool = false
    var isUnsearchable: Bool = false  // BOUND-051

    var hasNoResults: Bool { !keyword.isEmpty && results.isEmpty && !isUnsearchable }
    var resultSummary: String {
        guard !results.isEmpty else { return "" }
        return "\(currentIndex + 1)/\(results.count)"
    }

    // 供 PDFViewWrapper 持有引用以高亮结果
    weak var pdfView: PDFView?

    func performSearch(in document: PDFDocument) {
        // BOUND-051：检查可搜索性
        if !service.isSearchable(document) {
            isUnsearchable = true
            results = []
            return
        }
        isUnsearchable = false
        results = service.search(keyword: keyword, in: document, caseSensitive: caseSensitive)
        currentIndex = 0
        if let first = results.first {
            pdfView?.setCurrentSelection(first, animate: true)
            pdfView?.scrollSelectionToVisible(nil)
        }
    }

    // API-031
    func nextMatch() {
        guard !results.isEmpty else { return }
        currentIndex = (currentIndex + 1) % results.count
        highlight(results[currentIndex])
    }

    // API-032
    func previousMatch() {
        guard !results.isEmpty else { return }
        currentIndex = (currentIndex - 1 + results.count) % results.count
        highlight(results[currentIndex])
    }

    // API-033
    func dismissSearch() {
        isSearchBarVisible = false
        keyword = ""
        results = []
        currentIndex = 0
        isUnsearchable = false
        pdfView?.clearSelection()
    }

    private func highlight(_ selection: PDFSelection) {
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.scrollSelectionToVisible(nil)
    }
}
```

**验收标准**:
- [ ] 搜索词为空时 `results = []`，不调用 PDFKit
- [ ] `keyword.count > 100` 截断到前 100 字符
- [ ] 扫描件 PDF `isUnsearchable = true`
- [ ] `resultSummary` 格式为「3/12」

---

### T-05-02: SearchBarView

**输出文件**: `PDF-Ve/Features/Search/SearchBarView.swift`

**实现要求**:

```swift
import SwiftUI
import PDFKit

struct SearchBarView: View {
    @Bindable var searchVM: SearchViewModel
    var document: PDFDocument

    var body: some View {
        HStack(spacing: 6) {
            // 搜索输入框
            TextField("搜索…", text: $searchVM.keyword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                // 无结果时背景变红（AC-005-07）
                .background(searchVM.hasNoResults ? Color.red.opacity(0.3) : Color.clear)
                .cornerRadius(4)
                .onSubmit { searchVM.nextMatch() }          // Enter 下一个（AC-005-04）
                .onChange(of: searchVM.keyword) {
                    searchVM.performSearch(in: document)
                }

            // 结果数量（AC-005-03）
            if !searchVM.resultSummary.isEmpty {
                Text(searchVM.resultSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
            }

            // 无可搜索文本提示（BOUND-051）
            if searchVM.isUnsearchable {
                Text("此文档不含可搜索文本")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // 上一个 / 下一个
            Button(action: { searchVM.previousMatch() }) {
                Image(systemName: "chevron.up")
            }
            .disabled(searchVM.results.isEmpty)

            Button(action: { searchVM.nextMatch() }) {
                Image(systemName: "chevron.down")
            }
            .disabled(searchVM.results.isEmpty)

            // 大小写开关（AC-005-06）
            Toggle("Aa", isOn: $searchVM.caseSensitive)
                .toggleStyle(.button)
                .onChange(of: searchVM.caseSensitive) {
                    searchVM.performSearch(in: document)
                }

            // 关闭按钮（AC-005-08）
            Button(action: { searchVM.dismissSearch() }) {
                Image(systemName: "xmark")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
        // Esc 关闭（AC-005-08）
        .onKeyPress(.escape) { searchVM.dismissSearch(); return .handled }
    }
}
```

**验收标准**:
- [ ] Cmd+F 显示搜索栏（在 MainWindowView 中绑定快捷键）
- [ ] 输入关键词实时搜索并高亮第一个结果
- [ ] 无匹配时输入框背景变红（AC-005-07）
- [ ] Esc 关闭搜索栏，高亮消失（AC-005-08）

---

### T-05-03: 集成到 MainWindowView

在 `MainWindowView` 的 `.loaded` 状态下，在 PDF 阅读区上方添加搜索栏（条件显示）：

```swift
VStack(spacing: 0) {
    if searchVM.isSearchBarVisible {
        SearchBarView(searchVM: searchVM, document: doc)
        Divider()
    }
    PDFReaderView(document: doc, readerVM: readerVM)
}
// Cmd+F 快捷键
.keyboardShortcut("f", modifiers: .command) {
    searchVM.isSearchBarVisible = true
    // 聚焦搜索框（通过 FocusState）
}
// Cmd+G 下一个（AC-005-04）
.keyboardShortcut("g", modifiers: .command) { searchVM.nextMatch() }
// Cmd+Shift+G 上一个（AC-005-05）
.keyboardShortcut("g", modifiers: [.command, .shift]) { searchVM.previousMatch() }
```

**验收标准**:
- [ ] Cmd+F 打开搜索栏（AC-005-01）
- [ ] Cmd+G / Cmd+Shift+G 导航（AC-005-04, AC-005-05）

---

## 验收清单

- [ ] Cmd+F 打开搜索栏（AC-005-01）
- [ ] 搜索结果高亮，显示数量（AC-005-02, AC-005-03）
- [ ] Enter/Cmd+G 跳转下一个（AC-005-04）
- [ ] Shift+Enter/Cmd+Shift+G 跳转上一个（AC-005-05）
- [ ] 默认不区分大小写，可切换（AC-005-06）
- [ ] 无匹配时搜索框变红（AC-005-07）
- [ ] Esc 关闭搜索（AC-005-08）

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| API-030 search | T-05-01 SearchService | ✅ |
| API-031 nextMatch | T-05-01 SearchViewModel | ✅ |
| API-032 previousMatch | T-05-01 SearchViewModel | ✅ |
| API-033 dismissSearch | T-05-01 SearchViewModel | ✅ |
| BOUND-050 关键词长度 | T-05-01 | ✅ |
| BOUND-051 无可搜索文本 | T-05-01, T-05-02 | ✅ |
| STATE-004 搜索状态机 | T-05-01 | ✅ |
| AC-005-01~08 | T-05-01, T-05-02, T-05-03 | ✅ |
