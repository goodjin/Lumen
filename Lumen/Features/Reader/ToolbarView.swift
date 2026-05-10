import PDFVeCore
import SwiftUI

struct ReaderToolbarView: View {
    @Bindable var readerVM: ReaderViewModel
    var docVM: DocumentViewModel?
    @State private var pageInput: String = ""

    // 响应式布局：根据窗口宽度决定是否显示某些元素
    // 注意：这里使用固定值，实际宽度由父容器决定
    private var showZoomPercentage: Bool { true }
    private var showPageInput: Bool { true }

    var body: some View {
        HStack(spacing: 8) {
            // 后退/前进（导航历史）
            Button(action: { readerVM.goBack() }) {
                Image(systemName: "chevron.left.circle")
            }
            .disabled(!readerVM.canGoBack)
            .help("后退 (⌘[)")
            .accessibilityLabel("后退")

            Button(action: { readerVM.goForward() }) {
                Image(systemName: "chevron.right.circle")
            }
            .disabled(!readerVM.canGoForward)
            .help("前进 (⌘])")
            .accessibilityLabel("前进")

            Divider()

            // 上一页/下一页
            Button(action: { readerVM.goToPage(readerVM.currentPage - 1) }) {
                Image(systemName: "chevron.left")
            }
            .disabled(readerVM.currentPage <= 1)
            .accessibilityLabel("上一页")

            // 页码输入（AC-002-03, AC-002-04）
            if showPageInput {
                TextField("", text: $pageInput)
                    .frame(width: 45)
                    .multilineTextAlignment(.center)
                    .onSubmit {
                        if let page = Int(pageInput) {
                            readerVM.jumpToPage(page)
                        }
                        pageInput = "\(readerVM.currentPage)"
                    }
                    .onChange(of: readerVM.currentPage) {
                        pageInput = "\(readerVM.currentPage)"
                    }
                    .accessibilityLabel("页码输入")

                Text("/ \(readerVM.totalPages)")
                    .foregroundStyle(.secondary)
            }

            Button(action: { readerVM.goToPage(readerVM.currentPage + 1) }) {
                Image(systemName: "chevron.right")
            }
            .disabled(readerVM.currentPage >= readerVM.totalPages)
            .accessibilityLabel("下一页")

            Divider()

            // 缩放（AC-003-07）
            Button(action: { readerVM.zoomOut() }) { Image(systemName: "minus.magnifyingglass") }
                .accessibilityLabel("缩小")
            if showZoomPercentage {
                Text("\(Int(readerVM.zoomLevel * 100))%")
                    .frame(width: 50)
                    .monospacedDigit()
            }
            Button(action: { readerVM.zoomIn() }) { Image(systemName: "plus.magnifyingglass") }
                .accessibilityLabel("放大")

            // 全屏（AC-014-01）
            Button(action: { readerVM.toggleFullscreen() }) {
                Image(systemName: readerVM.isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
            }
            .help("全屏")
            .accessibilityLabel("全屏")

            // 页面显示模式
            Menu {
                ForEach(ReaderViewModel.DisplayMode.allCases, id: \.self) { mode in
                    Button {
                        readerVM.setDisplayMode(mode)
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if readerVM.displayMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: readerVM.displayMode == .two || readerVM.displayMode == .twoContinuous
                    ? "rectangle.split.2x1" : "doc.text")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28, height: 28)
            .help("页面显示模式")
            .accessibilityLabel("页面显示模式")

            // 阅读模式
            Menu {
                ForEach(ReaderViewModel.ReadingMode.allCases, id: \.self) { mode in
                    Button {
                        readerVM.setReadingMode(mode)
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if readerVM.readingMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: readerVM.readingMode == .normal
                    ? "sun.max" : "moon.fill")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28, height: 28)
            .help("阅读模式")
            .accessibilityLabel("阅读模式")

            Spacer()

            // 快速打开菜单
            OpenFileMenu(docVM: docVM)
                .accessibilityLabel("快速打开")
        }
        .frame(height: 44)
        .onAppear { pageInput = "\(readerVM.currentPage)" }
    }
}
