# P-10: MOD-09 窗口状态记忆模块

## 文档信息

- **计划编号**: P-10
- **批次**: 第1批
- **对应架构**: docs/v2/02-architecture/03-mod09-window-state.md
- **优先级**: P0
- **前置依赖**: 无

---

## 模块职责

记住用户偏好的窗口状态，包括：
1. 窗口大小（宽度、高度）
2. 窗口位置（x, y 坐标）
3. 侧边栏是否可见
4. 侧边栏标签页选择

**对应 PRD**: v2.0 新增功能

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-10-01 | WindowStateManager 窗口状态管理器 | 1 | ~80 | 无 |
| T-10-02 | MainWindowView 集成窗口状态 | 1 | ~100 | T-10-01 |
| T-10-03 | SidebarViewModel 集成标签页记忆 | 1 | ~60 | T-10-01 |

---

## 详细任务定义

### T-10-01: WindowStateManager 窗口状态管理器

**任务概述**: 创建窗口状态管理器，使用 UserDefaults 存储和恢复窗口状态。

**输出文件**: `PDF-Ve/Infrastructure/Persistence/WindowStateManager.swift`

**实现要求**:

```swift
import Foundation
import AppKit

@MainActor
class WindowStateManager: ObservableObject {
    static let shared = WindowStateManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastSidebarTab = "lastSidebarTab"
        static let sidebarVisible = "sidebarVisible"
        static let windowWidth = "windowWidth"
        static let windowHeight = "windowHeight"
        static let windowX = "windowX"
        static let windowY = "windowY"
        static let lastOpenedFilePath = "lastOpenedFilePath"
    }

    // 侧边栏标签页
    var lastSidebarTab: String {
        get { defaults.string(forKey: Keys.lastSidebarTab) ?? "目录" }
        set { defaults.set(newValue, forKey: Keys.lastSidebarTab) }
    }

    // 侧边栏可见性
    var sidebarVisible: Bool {
        get { defaults.object(forKey: Keys.sidebarVisible) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.sidebarVisible) }
    }

    // 窗口尺寸
    var savedWindowSize: CGSize? {
        get {
            let w = defaults.double(forKey: Keys.windowWidth)
            let h = defaults.double(forKey: Keys.windowHeight)
            guard w > 0 && h > 0 else { return nil }
            return CGSize(width: w, height: h)
        }
        set {
            if let size = newValue {
                defaults.set(size.width, forKey: Keys.windowWidth)
                defaults.set(size.height, forKey: Keys.windowHeight)
            }
        }
    }

    // 窗口位置
    var savedWindowOrigin: CGPoint? {
        get {
            let x = defaults.double(forKey: Keys.windowX)
            let y = defaults.double(forKey: Keys.windowY)
            guard x != 0 || y != 0 else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            if let origin = newValue {
                defaults.set(origin.x, forKey: Keys.windowX)
                defaults.set(origin.y, forKey: Keys.windowY)
            }
        }
    }

    // 最近打开文件路径
    var lastOpenedFilePath: String? {
        get { defaults.string(forKey: Keys.lastOpenedFilePath) }
        set { defaults.set(newValue, forKey: Keys.lastOpenedFilePath) }
    }

    func saveWindowState(frame: NSRect) {
        savedWindowOrigin = frame.origin
        savedWindowSize = frame.size
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: UserDefaults 正确读写
- [ ] **交互验证**: 窗口状态能保存
- [ ] **交互验证**: 窗口状态能恢复

**依赖**: 无

---

### T-10-02: MainWindowView 集成窗口状态

**任务概述**: 修改 MainWindowView，在应用启动时恢复窗口状态，在窗口关闭时保存状态。

**输出文件**: `PDF-Ve/Features/Document/MainWindowView.swift`（更新）

**实现要求**:

```swift
struct MainWindowView: View {
    @Environment(DocumentViewModel.self) var docVM
    // ... 其他 @State 变量

    // 窗口状态
    @State private var isSidebarVisible: Bool = true

    var body: some View {
        // ... 现有布局
        .onAppear {
            // 恢复侧边栏可见性
            isSidebarVisible = WindowStateManager.shared.sidebarVisible
        }
        .onDisappear {
            // 保存侧边栏可见性
            WindowStateManager.shared.sidebarVisible = isSidebarVisible
        }
    }
}
```

**窗口 Frame 恢复**（在 AppDelegate 中处理）：

```swift
// AppDelegate.swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // 恢复窗口大小
    if let savedSize = WindowStateManager.shared.savedWindowSize {
        window?.setContentSize(savedSize)
    }
    // 恢复窗口位置
    if let savedOrigin = WindowStateManager.shared.savedWindowOrigin {
        window?.setFrameOrigin(savedOrigin)
    }
}

func applicationWillTerminate(_ notification: Notification) {
    // 保存窗口状态
    if let frame = window?.frame {
        WindowStateManager.shared.saveWindowState(frame: frame)
    }
}
```

**验收标准**:
- [ ] **交互验证**: 应用启动时恢复窗口大小
- [ ] **交互验证**: 应用启动时恢复窗口位置
- [ ] **交互验证**: 应用关闭时保存窗口状态
- [ ] **交互验证**: 侧边栏可见性恢复和保存

**依赖**: T-10-01

---

### T-10-03: SidebarViewModel 集成标签页记忆

**任务概述**: 修改 SidebarViewModel，在标签页切换时保存当前选择，下次打开时恢复。

**输出文件**: `PDF-Ve/Features/Sidebar/SidebarViewModel.swift`（更新）

**实现要求**:

```swift
@MainActor
@Observable
class SidebarViewModel {
    // ... 其他属性

    // 当前选中的标签页（用于状态记忆）
    var currentTab: SidebarTab = .outline {
        didSet {
            WindowStateManager.shared.lastSidebarTab = currentTab.rawValue
        }
    }

    init(...) {
        // 恢复上次选中的标签页
        if let savedTab = SidebarTab(rawValue: WindowStateManager.shared.lastSidebarTab) {
            self.currentTab = savedTab
        }
    }
}
```

**SidebarView 更新**：

```swift
struct SidebarView: View {
    @Bindable var outlineVM: OutlineViewModel
    @Bindable var sidebarVM: SidebarViewModel
    // ...

    var body: some View {
        TabView(selection: $sidebarVM.currentTab) {
            // ...
        }
    }
}
```

**验收标准**:
- [ ] **交互验证**: 标签页切换时保存当前选择
- [ ] **交互验证**: 应用启动时恢复上次选择的标签页

**依赖**: T-10-01

---

## 验收清单

- [ ] 窗口大小记住上次设置
- [ ] 窗口位置记住上次位置
- [ ] 侧边栏可见性记住上次状态
- [ ] 侧边栏标签页记住上次选择

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| WindowStateManager | T-10-01 | ✅ |
| MainWindowView 窗口状态 | T-10-02 | ✅ |
| SidebarViewModel 标签页记忆 | T-10-03 | ✅ |
