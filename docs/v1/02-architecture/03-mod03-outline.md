# MOD-03: 目录导航模块

## 文档信息

- **模块编号**: MOD-03
- **版本**: v1.0
- **更新日期**: 2026-04-01
- **对应PRD**: FR-004
- **对应用户故事**: US-004

---

## 系统定位

```
┌────────────────────────────────┐
│  L5: SidebarView / OutlineView │
│  L4: SidebarViewModel          │
└────────────┬───────────────────┘
             │ ▼ 使用
┌────────────▼───────────────────┐
│  ★ MOD-03: 目录导航模块 ★      │
└────────────┬───────────────────┘
             │ ▼ 依赖
┌────────────▼───────────────────┐
│  PDFKit.PDFOutline             │
│  MOD-02 ReaderViewModel（跳转）│
└────────────────────────────────┘
```

### 核心职责

- 从 `PDFDocument` 读取 `PDFOutline` 目录树
- 在侧栏中展示最多 5 级层级目录
- 响应点击，通知 ReaderViewModel 跳转到目标页码
- 无目录时显示空状态提示

---

## 对应 PRD

| PRD 编号 | 内容 |
|---------|------|
| FR-004 | 目录导航，侧栏显示 PDF 目录树 |
| US-004 | 使用目录导航 |
| AC-004-01~06 | 全部验收条件 |

---

## 接口定义

### API-020: 加载目录

```swift
// OutlineViewModel
func loadOutline(from document: PDFDocument)
// 读取 document.outlineRoot，转换为 OutlineItem 树结构
// 最多递归 5 级（AC-004-03）
```

**后置影响**：
- `OutlineViewModel.items: [] → [OutlineItem]`
- `OutlineViewModel.hasOutline: false → true`

---

### API-021: 选择目录项（ViewModel 层）

```swift
// OutlineViewModel
func selectItem(_ item: OutlineItem, readerVM: ReaderViewModel)
// 调用 readerVM.goToPage(item.pageNumber)
```

**后置影响**：
- 直接变更：无（委托给 ReaderViewModel）
- 级联影响：同 API-010（ReaderViewModel.goToPage 的级联影响）

---

## View 层交互接口

### VIEW-API-001: 目录项点击跳转

**对应PRD**: US-004, AC-004-02

**手势**: 单击 (Tap)
**触发源**: `OutlineView.List` 中的 `OutlineItemRow`

**调用链**：
```
OutlineItemRow.onTapGesture
  → OutlineViewModel.selectItem(item, readerVM)
    → ReaderViewModel.goToPage(item.pageNumber)
```

**参数**：
| 参数 | 类型 | 说明 |
|-----|------|------|
| `item` | `OutlineItem` | 点击的目录项，包含 `pageNumber` |
| `readerVM` | `ReaderViewModel` | 用于执行页面跳转 |

---

### VIEW-API-002: 目录折叠/展开切换

**对应PRD**: AC-004-04

**手势**: 点击展开/折叠箭头（SwiftUI List 内置）
**触发源**: `OutlineView.List` 的 DisclosureGroup

**状态管理方案**：
```swift
// 方案：使用 SwiftUI List 的 children 参数自动管理
// OutlineItem 通过 childrenIfAny 控制展开箭头显示

extension OutlineItem {
    var childrenIfAny: [OutlineItem]? {
        children.isEmpty ? nil : children  // nil 时不显示展开箭头
    }
}
```

**说明**：
- 当前实现依赖 SwiftUI List 内置的折叠行为
- `isExpanded` 字段已定义但未接入（技术债务）
- 如需自定义展开状态，需改用 `@Bindable` 绑定 `isExpanded`

---

## 数据结构

```swift
struct OutlineItem: Identifiable {
    let id: UUID
    let title: String
    let pageNumber: Int          // 对应页码
    let depth: Int               // 层级深度（1~5）
    var children: [OutlineItem]  // 子目录项
    var isExpanded: Bool = true  // 折叠/展开状态（AC-004-04）
}
```

---

## 边界条件

| 条件 | 处理 |
|-----|------|
| PDF 无目录（outlineRoot == nil） | 显示「此文档无目录」（AC-004-05） |
| 目录项页码 > totalPages | 跳转到最后一页（AC-004-06 异常处理） |
| 目录层级 > 5 | 截断，不展示第 6 级及以下 |

---

## 实现文件

| 文件路径 | 职责 |
|---------|------|
| `Features/Outline/OutlineView.swift` | 目录树 SwiftUI 视图 |
| `Features/Outline/OutlineViewModel.swift` | 目录数据转换与状态 |
| `Shared/Models/OutlineItem.swift` | 数据模型 |

---

## 覆盖映射

| PRD 类型 | PRD 编号 | 架构元素 | 状态 |
|---------|---------|---------|------|
| 功能需求 | FR-004 | MOD-03, OutlineView | ✅ |
| 用户故事 | US-004 | API-020, API-021 | ✅ |
| 验收标准 | AC-004-01~06 | 边界条件全覆盖 | ✅ |
