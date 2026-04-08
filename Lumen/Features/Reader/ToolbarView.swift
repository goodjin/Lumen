import PDFVeCore
import SwiftUI

struct ReaderToolbarView: View {
    @Bindable var readerVM: ReaderViewModel
    @State private var pageInput: String = ""

    // 响应式布局：根据窗口宽度决定是否显示某些元素
    // 注意：这里使用固定值，实际宽度由父容器决定
    private var showZoomPercentage: Bool { true }
    private var showPageInput: Bool { true }

    var body: some View {
        HStack(spacing: 8) {
            // 上一页/下一页
            Button(action: { readerVM.goToPage(readerVM.currentPage - 1) }) {
                Image(systemName: "chevron.left")
            }
            .disabled(readerVM.currentPage <= 1)

            // 页码输入（AC-002-03, AC-002-04）
            if showPageInput {
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
            }

            Button(action: { readerVM.goToPage(readerVM.currentPage + 1) }) {
                Image(systemName: "chevron.right")
            }
            .disabled(readerVM.currentPage >= readerVM.totalPages)

            Divider()

            // 缩放（AC-003-07）
            Button(action: { readerVM.zoomOut() }) { Image(systemName: "minus.magnifyingglass") }
            if showZoomPercentage {
                Text("\(Int(readerVM.zoomLevel * 100))%")
                    .frame(width: 50)
                    .monospacedDigit()
            }
            Button(action: { readerVM.zoomIn() }) { Image(systemName: "plus.magnifyingglass") }

            // 全屏（AC-014-01）
            Button(action: { readerVM.toggleFullscreen() }) {
                Image(systemName: readerVM.isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
            }

            Spacer()

            // 快速打开菜单
            OpenFileMenu()
        }
        .frame(height: 44)
        .onAppear { pageInput = "\(readerVM.currentPage)" }
    }
}
