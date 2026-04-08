# P-03: MOD-02 PDF 渲染模块

## 文档信息

- **计划编号**: P-03
- **批次**: 第2批
- **对应架构**: docs/v1/02-architecture/03-mod02-reader.md
- **优先级**: P0
- **前置依赖**: P-01, P-02

---

## 模块职责

使用 PDFKit 渲染 PDF 页面，实现滚动翻页、缩放（含快捷键/手势）、全屏模式、页码同步。对应 PRD: FR-002, FR-003, FR-014。

---

## 任务清单

| 任务编号 | 任务名称 | 文件数 | 预估行数 | 依赖 |
|---------|---------|-------|---------|------|
| T-03-01 | ReaderViewModel | 1 | ~100 | P-02 |
| T-03-02 | PDFViewWrapper（NSViewRepresentable） | 1 | ~150 | T-03-01 |
| T-03-03 | PDFReaderView（SwiftUI 容器） | 1 | ~80 | T-03-02 |
| T-03-04 | ToolbarView（页码 + 缩放） | 1 | ~100 | T-03-01 |
| T-03-05 | MainWindowView 集成（替换占位） | 1 | ~40 | T-03-03, T-03-04 |

---

## 详细任务定义

### T-03-01: ReaderViewModel

**输出文件**: `PDF-Ve/Features/Reader/ReaderViewModel.swift`

**实现要求**:

```swift
import PDFKit
import SwiftUI

@MainActor
@Observable
class ReaderViewModel {
    enum ZoomMode { case actual, fitWidth, fitPage }

    var currentPage: Int = 1
    var totalPages: Int = 0
    var zoomLevel: Double = 1.0          // 1.0 = 100%
    var zoomMode: ZoomMode = .actual
    var isFullscreen: Bool = false

    // 供 PDFViewWrapper 持有真实的 PDFView 引用
    weak var pdfView: PDFView?

    // API-010: 跳转页码（BOUND-010：clamp）
    func goToPage(_ pageNumber: Int) {
        guard totalPages > 0 else { return }
        let clamped = max(1, min(pageNumber, totalPages))
        guard let page = pdfView?.document?.page(at: clamped - 1) else { return }
        pdfView?.go(to: page)
    }

    // API-011: 缩放系列
    func zoomIn() {
        let newLevel = min(zoomLevel + 0.1, 5.0)
        setZoom(newLevel)
    }

    func zoomOut() {
        let newLevel = max(zoomLevel - 0.1, 0.1)
        setZoom(newLevel)
    }

    func setZoom(_ level: Double) {
        let clamped = max(0.1, min(level, 5.0))
        zoomLevel = clamped
        zoomMode = .actual
        pdfView?.scaleFactor = clamped
    }

    func setZoomMode(_ mode: ZoomMode) {
        zoomMode = mode
        switch mode {
        case .actual:   pdfView?.scaleFactor = 1.0; zoomLevel = 1.0
        case .fitWidth:  pdfView?.autoScales = false
                         // 计算适合宽度的 scaleFactor
                         if let page = pdfView?.currentPage,
                            let view = pdfView {
                             let pageWidth = page.bounds(for: .mediaBox).width
                             let viewWidth = view.bounds.width - 20
                             let scale = viewWidth / pageWidth
                             pdfView?.scaleFactor = scale
                             zoomLevel = scale
                         }
        case .fitPage:  pdfView?.autoScales = true
                        zoomLevel = pdfView?.scaleFactor ?? 1.0
        }
    }

    // API-012: 全屏切换
    func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
        isFullscreen.toggle()
    }

    // 由 PDFViewWrapper Coordinator 回调，同步当前页码
    func updateCurrentPage(_ page: Int) {
        currentPage = page
    }
}
```

**验收标准**:
- [ ] `goToPage(0)` 跳到第 1 页，`goToPage(999)` 跳到最后一页
- [ ] `zoomIn()` 到 500% 后继续调用不超过上限
- [ ] `zoomOut()` 到 10% 后继续调用不低于下限

**依赖**: P-02

---

### T-03-02: PDFViewWrapper（NSViewRepresentable）

**输出文件**: `PDF-Ve/Features/Reader/PDFViewWrapper.swift`

**实现要求**:

```swift
import SwiftUI
import PDFKit

struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = false
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false, withViewOptions: nil)
        // 将 pdfView 引用传给 ViewModel
        readerVM.pdfView = pdfView
        readerVM.totalPages = document.pageCount
        // 恢复上次页码（由外部设置 readerVM.currentPage 触发）
        // 监听页面变化通知
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // 当 readerVM.zoomLevel 变化时同步
        if abs(pdfView.scaleFactor - readerVM.zoomLevel) > 0.001 {
            pdfView.scaleFactor = readerVM.zoomLevel
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(readerVM: readerVM)
    }

    class Coordinator: NSObject {
        let readerVM: ReaderViewModel
        init(readerVM: ReaderViewModel) { self.readerVM = readerVM }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let doc = pdfView.document,
                  let index = doc.index(for: currentPage) else { return }
            Task { @MainActor in
                self.readerVM.updateCurrentPage(index + 1)
                self.readerVM.zoomLevel = pdfView.scaleFactor
            }
        }
    }
}
```

**验收标准**:
- [ ] PDF 内容正确渲染，支持滚动（AC-002-01）
- [ ] `PDFViewPageChanged` 通知触发后 `readerVM.currentPage` 正确更新
- [ ] 键盘翻页（PDFView 内置支持 ↑↓ / PageUp/Down）正常工作（AC-002-02）

**依赖**: T-03-01

---

### T-03-03: PDFReaderView

**输出文件**: `PDF-Ve/Features/Reader/PDFReaderView.swift`

**实现要求**:

```swift
import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel

    var body: some View {
        PDFViewWrapper(document: document, readerVM: readerVM)
            // 触控板捏合缩放（AC-003-05）
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        readerVM.setZoom(readerVM.zoomLevel * value.magnification)
                    }
            )
            // 键盘快捷键（AC-003-01~04）
            .onKeyPress(.init("+"), action: { readerVM.zoomIn(); return .handled })
            .onKeyPress(.init("-"), action: { readerVM.zoomOut(); return .handled })
    }
}
```

**验收标准**:
- [ ] 显示 PDF 内容，可滚动
- [ ] 触控板捏合缩放有效

**依赖**: T-03-02

---

### T-03-04: ToolbarView（页码 + 缩放）

**输出文件**: `PDF-Ve/Features/Reader/ToolbarView.swift`

**实现要求**:

```swift
import SwiftUI

struct ReaderToolbarView: View {
    @Bindable var readerVM: ReaderViewModel
    @State private var pageInput: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // 上一页/下一页
            Button(action: { readerVM.goToPage(readerVM.currentPage - 1) }) {
                Image(systemName: "chevron.left")
            }
            .disabled(readerVM.currentPage <= 1)

            // 页码输入（AC-002-03, AC-002-04）
            TextField("", text: $pageInput)
                .frame(width: 45)
                .multilineTextAlignment(.center)
                .onSubmit {
                    if let page = Int(pageInput) {
                        readerVM.goToPage(page)
                    }
                    pageInput = "\(readerVM.currentPage)"
                }
                .onChange(of: readerVM.currentPage) {
                    pageInput = "\(readerVM.currentPage)"
                }
            Text("/ \(readerVM.totalPages)")
                .foregroundStyle(.secondary)

            Button(action: { readerVM.goToPage(readerVM.currentPage + 1) }) {
                Image(systemName: "chevron.right")
            }
            .disabled(readerVM.currentPage >= readerVM.totalPages)

            Divider()

            // 缩放（AC-003-07）
            Button(action: { readerVM.zoomOut() }) { Image(systemName: "minus.magnifyingglass") }
            Text("\(Int(readerVM.zoomLevel * 100))%")
                .frame(width: 50)
                .monospacedDigit()
            Button(action: { readerVM.zoomIn() }) { Image(systemName: "plus.magnifyingglass") }

            // 全屏（AC-014-01）
            Button(action: { readerVM.toggleFullscreen() }) {
                Image(systemName: readerVM.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
        }
        .onAppear { pageInput = "\(readerVM.currentPage)" }
    }
}
```

**验收标准**:
- [ ] **数据展示验证**: 工具栏显示当前页 / 总页数（AC-002-03）
- [ ] **数据展示验证**: 缩放百分比实时更新（AC-003-07）
- [ ] **布局验证**: 工具栏高度固定 44pt，不挤占 PDF 渲染区域（UI-Layout-001）
- [ ] **布局验证**: 总工具栏高度 = 系统工具栏（.unified 样式）+ 自定义工具栏 ≤ 60pt
- [ ] **布局验证**: 窗口宽度 < 600pt 时隐藏缩放百分比文字，< 400pt 时隐藏页码输入框
- [ ] **交互验证**: 页码输入框回车后跳转，非数字输入恢复当前页码（BOUND-010）
- [ ] **交互验证**: 点击上一页/下一页按钮正确触发页面跳转
- [ ] **交互验证**: 点击缩放按钮正确触发缩放变更
- [ ] **交互验证**: 点击全屏按钮正确触发全屏切换

**依赖**: T-03-01

---

### T-03-05: MainWindowView 集成

**输出文件**: `PDF-Ve/Features/Document/MainWindowView.swift`（更新）

**实现要求**: 将 P-02 中的占位 Text 替换为真实的 `PDFReaderView` + `ReaderToolbarView`，工具栏通过 `.toolbar {}` 集成，并注册 Cmd+1/2/0 快捷键。

```swift
// 在 MainWindowView 中，loaded 状态下渲染：
case .loaded(let doc, let url):
    PDFReaderView(document: doc, readerVM: readerVM)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ReaderToolbarView(readerVM: readerVM)
            }
        }
        .onDisappear {
            // 关闭时保存阅读位置（Rule-002）
            docVM.close(currentPage: readerVM.currentPage, zoomLevel: readerVM.zoomLevel)
        }
        // Cmd+1/2/0 缩放快捷键（AC-003-02~04）
        .keyboardShortcut("0", modifiers: .command) { readerVM.setZoom(1.0) }
        .keyboardShortcut("1", modifiers: .command) { readerVM.setZoomMode(.fitWidth) }
        .keyboardShortcut("2", modifiers: .command) { readerVM.setZoomMode(.fitPage) }
```

**验收标准**:
- [ ] 打开文件后 PDF 内容显示在主区域
- [ ] 工具栏页码/缩放实时更新
- [ ] 关闭窗口时调用 `docVM.close()` 保存状态

**依赖**: T-03-03, T-03-04

---

## 验收清单

- [ ] 打开任意 PDF 文件，内容正确渲染
- [ ] 鼠标滚轮/触控板可上下滚动翻页（AC-002-01）
- [ ] 键盘 ↑↓ / PageUp/Down 翻页（AC-002-02）
- [ ] Cmd++ / Cmd+- 步进缩放 10%（AC-003-01）
- [ ] Cmd+0/1/2 切换缩放模式（AC-003-02~04）
- [ ] 触控板双指捏合缩放（AC-003-05）
- [ ] 缩放不超过 10%~500%（AC-003-06）
- [ ] Cmd+Ctrl+F 进入全屏（AC-014-01）

## 覆盖映射

| 架构元素 | 任务 | 状态 |
|---------|------|------|
| API-010 goToPage | T-03-01 | ✅ |
| API-011 缩放系列 | T-03-01 | ✅ |
| API-012 toggleFullscreen | T-03-01 | ✅ |
| PDFViewWrapper | T-03-02 | ✅ |
| BOUND-010 页码边界 | T-03-01 | ✅ |
| BOUND-011 缩放范围边界 | T-03-01 | ✅ |
| AC-002-01~05 | T-03-02, T-03-04 | ✅ |
| AC-003-01~07 | T-03-01, T-03-04 | ✅ |
| AC-014-01~04 | T-03-01, T-03-05 | ✅ |
