# P-09: MOD-08 页面导航 Fallback 模块

## 文档信息

- **计划编号**: P-09
- **批次**: 第1批
- **对应架构**: docs/v2/02-architecture/03-mod08-page-nav.md
- **优先级**: P0
- **前置依赖**: 无（基于 v1.0 MOD-07 侧栏）

---

## 模块职责

当 PDF 文档没有目录（outline）时，在侧栏的「目录」Tab 中显示页面导航列表（"第1页"、"第2页"...），用户可以点击跳转到对应页面。

**对应 PRD**: v2.0 新增功能

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-09-01 | PageNavigationView 页面导航视图 | 1 | ~100 | 无 |
| T-09-02 | OutlineView 集成 Fallback | 1 | ~60 | T-09-01 |
| T-09-03 | 窗口状态保存/恢复 | 1 | ~80 | 无 |

---

## 详细任务定义

### T-09-01: PageNavigationView 页面导航视图

**任务概述**: 创建页面导航视图组件，当 PDF 无目录时显示页面列表。

**输出文件**: `PDF-Ve/Features/Sidebar/PageNavigationView.swift`

**实现要求**:

```swift
import SwiftUI
import PDFKit

struct PageNavigationView: View {
    let document: PDFDocument
    var readerVM: ReaderViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(1...document.pageCount, id: \.self) { pageNumber in
                    PageNavigationRow(
                        pageNumber: pageNumber,
                        isCurrentPage: readerVM.currentPage == pageNumber
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        readerVM.goToPage(pageNumber)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PageNavigationRow: View {
    let pageNumber: Int
    let isCurrentPage: Bool

    var body: some View {
        HStack {
            Image(systemName: "doc")
                .foregroundStyle(isCurrentPage ? .accentColor : .secondary)
                .frame(width: 20)
            Text("第 \(pageNumber) 页")
                .font(.body)
                .foregroundStyle(isCurrentPage ? .primary : .secondary)
            Spacer()
            if isCurrentPage {
                Image(systemName: "checkmark")
                    .foregroundStyle(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrentPage ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 列表显示"第X页"格式，每页一条
- [ ] **数据展示验证**: 当前页有高亮背景和勾选标记
- [ ] **布局验证**: 页面列表撑满侧栏可用高度
- [ ] **交互验证**: 点击页面项触发跳转
- [ ] **交互验证**: 当前页变更时高亮同步更新

**依赖**: 无

---

### T-09-02: OutlineView 集成 Fallback

**任务概述**: 修改 OutlineView，当 `outlineVM.hasOutline == false` 时显示 PageNavigationView。

**输出文件**: `PDF-Ve/Features/Outline/OutlineView.swift`（更新）

**实现要求**:

```swift
struct OutlineView: View {
    @Bindable var outlineVM: OutlineViewModel
    var readerVM: ReaderViewModel
    var document: PDFDocument

    var body: some View {
        Group {
            if !outlineVM.hasOutline {
                // Fallback: 显示页面导航
                PageNavigationView(document: document, readerVM: readerVM)
            } else {
                // 原有目录结构
                List(outlineVM.items, children: \.childrenIfAny) { item in
                    Button(action: {
                        outlineVM.selectItem(item, readerVM: readerVM)
                    }) {
                        OutlineItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 有目录时显示目录结构，无目录时显示页面列表
- [ ] **交互验证**: 点击目录项正常工作
- [ ] **交互验证**: 点击页面项正常工作（Fallback）

**依赖**: T-09-01

---

### T-09-03: 侧边栏标签页状态保存/恢复

**任务概述**: 记住用户最后选择的侧边栏标签页，下次打开文档时自动切换到该标签。

**输出文件**: `PDF-Ve/Infrastructure/Persistence/WindowStateManager.swift`

**实现要求**:

```swift
import Foundation

@MainActor
class WindowStateManager: ObservableObject {
    static let shared = WindowStateManager()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let lastSidebarTab = "lastSidebarTab"
        static let windowWidth = "windowWidth"
        static let windowHeight = "windowHeight"
        static let windowX = "windowX"
        static let windowY = "windowY"
    }

    // 侧边栏标签页
    var lastSidebarTab: SidebarTab {
        get {
            guard let raw = defaults.string(forKey: Keys.lastSidebarTab),
                  let tab = SidebarTab(rawValue: raw) else {
                return .outline
            }
            return tab
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.lastSidebarTab)
        }
    }

    // 窗口尺寸
    var windowFrame: NSRect {
        get {
            let x = defaults.double(forKey: Keys.windowX)
            let y = defaults.double(forKey: Keys.windowY)
            let w = defaults.double(forKey: Keys.windowWidth)
            let h = defaults.double(forKey: Keys.windowHeight)
            return NSRect(x: x, y: y, width: w, height: h)
        }
        set {
            defaults.set(newValue.origin.x, forKey: Keys.windowX)
            defaults.set(newValue.origin.y, forKey: Keys.windowY)
            defaults.set(newValue.size.width, forKey: Keys.windowWidth)
            defaults.set(newValue.size.height, forKey: Keys.windowHeight)
        }
    }

    func saveWindowState(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) {
        defaults.set(x, forKey: Keys.windowX)
        defaults.set(y, forKey: Keys.windowY)
        defaults.set(width, forKey: Keys.windowWidth)
        defaults.set(height, forKey: Keys.windowHeight)
    }
}
```

**验收标准**:
- [ ] **数据流转验证**: 标签页切换时保存到 UserDefaults
- [ ] **数据流转验证**: 应用启动时从 UserDefaults 恢复
- [ ] **交互验证**: 恢复的标签页正确显示

**依赖**: 无

---

## 验收清单

- [ ] PDF 无目录时侧栏「目录」Tab 显示页面列表
- [ ] 页面列表显示"第X页"格式
- [ ] 当前页有视觉高亮
- [ ] 点击页面能跳转到对应页
- [ ] 侧边栏标签页记住上次选择

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| PageNavigationView | T-09-01 | ✅ |
| OutlineView Fallback | T-09-02 | ✅ |
| WindowStateManager | T-09-03 | ✅ |
