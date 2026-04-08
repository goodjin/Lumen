# P-04: MOD-03 目录导航模块

## 文档信息

- **计划编号**: P-04
- **批次**: 第2批
- **对应架构**: docs/v1/02-architecture/03-mod03-outline.md
- **优先级**: P0
- **前置依赖**: P-03

---

## 模块职责

从 PDFDocument 读取目录树，在侧栏展示，点击跳转。对应 PRD: FR-004, US-004。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-04-01 | OutlineViewModel（解析 PDFOutline） | 1 | ~80 | P-03 |
| T-04-02a | OutlineView 目录列表渲染 | 1 | ~80 | T-04-01 |
| T-04-02b | OutlineView 目录点击跳转（VIEW-API-001） | 1 | ~40 | T-04-02a |
| T-04-03 | 侧栏骨架 SidebarView（含 Cmd+T） | 1 | ~60 | T-04-02b |

---

## 详细任务定义

### T-04-01: OutlineViewModel

**输出文件**: `PDF-Ve/Features/Outline/OutlineViewModel.swift`

**实现要求**:

```swift
import PDFKit
import SwiftUI

@MainActor
@Observable
class OutlineViewModel {
    var items: [OutlineItem] = []
    var hasOutline: Bool = false

    // API-020：加载目录（最多 5 级）
    func loadOutline(from document: PDFDocument) {
        guard let root = document.outlineRoot else {
            hasOutline = false
            items = []
            return
        }
        hasOutline = true
        items = parseOutline(root, depth: 1)
    }

    private func parseOutline(_ outline: PDFOutline, depth: Int) -> [OutlineItem] {
        guard depth <= 5 else { return [] }   // 最多 5 级（AC-004-03）
        var result: [OutlineItem] = []
        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }
            let pageNum = child.destination?.page.flatMap { doc in
                child.document?.index(for: doc)
            }.map { $0 + 1 } ?? 1
            let children = parseOutline(child, depth: depth + 1)
            let item = OutlineItem(
                title: child.label ?? "（无标题）",
                pageNumber: pageNum,
                depth: depth,
                children: children
            )
            result.append(item)
        }
        return result
    }

    // API-021：点击目录项，通知 ReaderViewModel 跳转
    func selectItem(_ item: OutlineItem, readerVM: ReaderViewModel) {
        readerVM.goToPage(item.pageNumber)
    }
}
```

**验收标准**:
- [ ] 有目录的 PDF 解析后 `hasOutline = true`，`items` 非空
- [ ] 无目录的 PDF `hasOutline = false`，`items = []`
- [ ] 目录层级超过 5 级时截断

**依赖**: P-03（PDFDocument、ReaderViewModel）

---

### T-04-02a: OutlineView 目录列表渲染

**输出文件**: `PDF-Ve/Features/Outline/OutlineView.swift`

**实现要求**:

```swift
import SwiftUI

struct OutlineView: View {
    @Bindable var outlineVM: OutlineViewModel
    var readerVM: ReaderViewModel

    var body: some View {
        Group {
            if !outlineVM.hasOutline {
                ContentUnavailableView("此文档无目录", systemImage: "list.bullet.indent")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(outlineVM.items, children: \.childrenIfAny) { item in
                    OutlineItemRow(item: item)
                        // T-04-02b: 点击跳转在独立任务中实现
                        .onTapGesture {
                            outlineVM.selectItem(item, readerVM: readerVM)
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct OutlineItemRow: View {
    let item: OutlineItem
    var body: some View {
        HStack {
            Text(item.title)
                .lineLimit(2)
            Spacer()
            Text("\(item.pageNumber)")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.leading, CGFloat((item.depth - 1) * 12))
    }
}

// children 为空时返回 nil，让 List 不显示展开箭头
extension OutlineItem {
    var childrenIfAny: [OutlineItem]? {
        children.isEmpty ? nil : children
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 有目录时显示层级树，支持折叠/展开（AC-004-04）
- [ ] **数据展示验证**: 无目录时显示「此文档无目录」空状态（AC-004-05）
- [ ] **数据展示验证**: 目录项显示标题和页码，层级缩进正确（AC-004-03）
- [ ] **布局验证**: 侧栏宽度 240pt，目录列表撑满可用高度（UI-Layout-003）

**依赖**: T-04-01

---

### T-04-02b: OutlineView 目录点击跳转（VIEW-API-001）

**任务概述**: 实现目录项点击跳转功能。这是 VIEW-API-001 的独立实现任务，验证点击 → 跳转 → 目标位置正确加载的完整链路。

**输出文件**: `PDF-Ve/Features/Outline/OutlineView.swift`（更新点击处理）

**实现要求**:

已在 T-04-02a 中预留 `.onTapGesture`，本任务验证并完善交互逻辑：

```swift
// 验证调用链完整
List(outlineVM.items, children: \.childrenIfAny) { item in
    OutlineItemRow(item: item)
        .onTapGesture {
            // VIEW-API-001: 目录项点击跳转
            // 调用链: OutlineItemRow.onTapGesture 
            //   → OutlineViewModel.selectItem(item, readerVM)
            //     → ReaderViewModel.goToPage(item.pageNumber)
            outlineVM.selectItem(item, readerVM: readerVM)
        }
}
```

**验收标准**:
- [ ] **交互验证**: 点击目录项触发 `onTapGesture` 事件
- [ ] **数据流转验证**: `outlineVM.selectItem()` 被正确调用，参数传递正确
- [ ] **级联影响验证**: `ReaderViewModel.goToPage()` 被正确调用
- [ ] **端到端验证**: 点击目录项后主视图跳转到对应页面（AC-004-02）

**依赖**: T-04-02a

---

### T-04-03: SidebarView 骨架

**输出文件**: `PDF-Ve/Features/Sidebar/SidebarView.swift`

**实现要求**: 创建包含「目录」Tab 的侧栏视图骨架，后续 P-08 继续添加标注/书签/缩略图 Tab。Cmd+T 控制侧栏显隐。

```swift
import SwiftUI

struct SidebarView: View {
    var outlineVM: OutlineViewModel
    var readerVM: ReaderViewModel

    var body: some View {
        TabView {
            OutlineView(outlineVM: outlineVM, readerVM: readerVM)
                .tabItem { Label("目录", systemImage: "list.bullet.indent") }
            // P-08 将添加更多 Tab
        }
        .frame(minWidth: 200, idealWidth: 240)
    }
}
```

并在 `MainWindowView` 中：
- 使用 `NavigationSplitView` 或 `HSplitView` 组合侧栏和阅读区
- 添加 `@State var isSidebarVisible = true`，Cmd+T 切换

**验收标准**:
- [ ] **数据展示验证**: 侧栏显示目录 Tab
- [ ] **布局验证**: 侧栏宽度 240pt，高度撑满父容器减去工具栏高度（UI-Layout-003）
- [ ] **交互验证**: Cmd+T 可隐藏/显示侧栏（AC-004-06）

**依赖**: T-04-02b

---

## 验收清单

- [ ] 有目录的 PDF 打开后侧栏「目录」Tab 显示层级结构（AC-004-01）
- [ ] 目录列表正确渲染（AC-004-01，T-04-02a）
- [ ] 点击目录项主视图跳转（AC-004-02，T-04-02b）
- [ ] 支持最多 5 级缩进（AC-004-03，T-04-02a）
- [ ] 目录层级可折叠展开（AC-004-04，T-04-02a）
- [ ] 无目录 PDF 显示提示（AC-004-05，T-04-02a）
- [ ] Cmd+T 显隐侧栏（AC-004-06，T-04-03）

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| API-020 loadOutline | T-04-01 | ✅ |
| API-021 selectOutlineItem | T-04-01 | ✅ |
| VIEW-API-001 目录点击跳转 | T-04-02b | ✅ |
| VIEW-API-002 目录折叠/展开 | T-04-02a | ✅ |
| UI-Layout-003 侧栏布局 | T-04-03 | ✅ |
| OutlineItem 数据模型 | P-01 T-01-02 | ✅ |
| AC-004-01~06 | T-04-01, T-04-02a, T-04-02b, T-04-03 | ✅ |
