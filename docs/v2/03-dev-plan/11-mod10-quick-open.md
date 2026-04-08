# P-11: MOD-10 快速打开菜单模块

## 文档信息

- **计划编号**: P-11
- **批次**: 第1批
- **对应架构**: docs/v2/02-architecture/03-mod10-quick-open.md
- **优先级**: P0
- **前置依赖**: 无

---

## 模块职责

在工具栏右侧增加一个快速打开下拉按钮，提供：
1. **打开文件**：打开系统文件选择器选择 PDF
2. **打开网络文件**：输入 URL 下载并打开 PDF
3. **最近文件**：显示最近打开的文档快速访问

**对应 PRD**: v2.0 新增功能

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-11-01 | OpenFileMenu 下拉菜单组件 | 1 | ~120 | 无 |
| T-11-02 | ToolbarView 集成快速打开 | 1 | ~60 | T-11-01 |
| T-11-03 | 网络文件下载功能 | 1 | ~80 | 无 |

---

## 详细任务定义

### T-11-01: OpenFileMenu 下拉菜单组件

**任务概述**: 创建快速打开下拉菜单组件，包含打开文件、打开网络文件、最近文件三个选项。

**输出文件**: `PDF-Ve/Features/Document/OpenFileMenu.swift`

**实现要求**:

```swift
import SwiftUI

struct OpenFileMenu: View {
    @Environment(DocumentViewModel.self) var docVM
    @State private var showNetworkDialog = false
    @State private var networkURL = ""

    var body: some View {
        Menu {
            // 打开文件
            Button(action: {
                Task { await docVM.showOpenPanel() }
            }) {
                Label("打开文件...", systemImage: "doc.badge.plus")
            }

            // 打开网络文件
            Button(action: {
                showNetworkDialog = true
            }) {
                Label("打开网络文件...", systemImage: "globe")
            }

            Divider()

            // 最近文件
            if !docVM.recentDocuments.isEmpty {
                Menu("最近文件") {
                    ForEach(docVM.recentDocuments.prefix(5), id: \.filePath) { record in
                        Button(action: {
                            Task { await docVM.openRecent(record) }
                        }) {
                            Text(record.fileName)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                Text("无最近文件")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 16))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28, height: 28)
        .alert("打开网络文件", isPresented: $showNetworkDialog) {
            TextField("输入 PDF URL", text: $networkURL)
            Button("取消", role: .cancel) {
                networkURL = ""
            }
            Button("打开") {
                Task {
                    if let url = URL(string: networkURL) {
                        await openNetworkFile(url: url)
                    }
                    networkURL = ""
                }
            }
        } message: {
            Text("请输入 PDF 文件的 URL 地址")
        }
    }

    private func openNetworkFile(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let doc = PDFDocument(data: data) {
                // 创建临时文件
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try data.write(to: tempURL)
                await docVM.open(url: tempURL)
            }
        } catch {
            print("打开网络文件失败: \(error)")
        }
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 菜单正确展开
- [ ] **数据展示验证**: 最近文件列表正确显示（最多5条）
- [ ] **数据展示验证**: 无最近文件时显示提示
- [ ] **交互验证**: 点击打开文件触发文件选择器
- [ ] **交互验证**: 点击打开网络文件显示输入框
- [ ] **交互验证**: 点击最近文件直接打开

**依赖**: 无

---

### T-11-02: ToolbarView 集成快速打开

**任务概述**: 修改 ToolbarView，在右侧添加 OpenFileMenu 下拉菜单。

**输出文件**: `PDF-Ve/Features/Reader/ToolbarView.swift`（更新）

**实现要求**:

```swift
struct ReaderToolbarView: View {
    @Bindable var readerVM: ReaderViewModel
    @Environment(DocumentViewModel.self) var docVM

    var body: some View {
        HStack(spacing: 8) {
            // 原有工具栏内容...

            Spacer()

            // 快速打开菜单
            OpenFileMenu()
        }
        .frame(height: 44)
    }
}
```

**验收标准**:
- [ ] **布局验证**: 快速打开按钮在工具栏最右侧
- [ ] **布局验证**: 按钮高度 28pt，不超出工具栏 44pt 高度
- [ ] **交互验证**: 下拉菜单正常展开

**依赖**: T-11-01

---

### T-11-03: 菜单栏文件路径显示

**任务概述**: 在菜单栏标题区域显示当前打开文件的路径。

**输出文件**: `PDF_VeApp.swift`（更新）

**实现要求**:

```swift
@main
struct PDF_VeApp: App {
    // ...

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(docVM)
        }
        .modelContainer(persistence.container)
        .commands {
            PDFVeCommands(docVM: docVM)
        }
        // 设置窗口标题显示文件路径
        .defaultSize(width: 800, height: 600)
    }
}

// 修改 WindowGroup 使用 NSWindow 实现自定义标题
```

**使用 NSWindow 方案**：

```swift
// AppDelegate.swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = MainWindowView()
            .environment(docVM)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "PDF-Ve"
        window.center()

        // 恢复窗口状态
        if let savedSize = WindowStateManager.shared.savedWindowSize {
            window.setContentSize(savedSize)
        }
        if let savedOrigin = WindowStateManager.shared.savedWindowOrigin {
            window.setFrameOrigin(savedOrigin)
        }

        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowStateManager.shared.saveWindowState(frame: window.frame)
    }
}
```

**在 DocumentViewModel 中更新标题**：

```swift
extension DocumentViewModel {
    func updateWindowTitle() {
        if case .loaded(_, let url) = state {
            NSApp.keyWindow?.title = "PDF-Ve - \(url.lastPathComponent)"
        } else {
            NSApp.keyWindow?.title = "PDF-Ve"
        }
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 窗口标题显示文件名
- [ ] **交互验证**: 打开文件后标题更新
- [ ] **交互验证**: 关闭文件后标题恢复

**依赖**: T-10-01

---

## 验收清单

- [ ] 工具栏右侧显示快速打开按钮
- [ ] 点击按钮显示下拉菜单
- [ ] 下拉菜单包含：打开文件、打开网络文件、最近文件
- [ ] 打开文件功能正常
- [ ] 打开网络文件功能正常（输入 URL）
- [ ] 最近文件列表正确显示
- [ ] 窗口标题显示当前文件路径

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| OpenFileMenu | T-11-01 | ✅ |
| ToolbarView 集成 | T-11-02 | ✅ |
| 菜单栏文件路径 | T-11-03 | ✅ |
