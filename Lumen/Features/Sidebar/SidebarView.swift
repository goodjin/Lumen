import PDFVeCore
import SwiftUI
import PDFKit

struct SidebarView: View {
    @Bindable var outlineVM: OutlineViewModel
    @Bindable var sidebarVM: SidebarViewModel
    var readerVM: ReaderViewModel
    var document: PDFDocument
    var thumbnailProvider: ThumbnailProvider

    var body: some View {
        TabView(selection: $sidebarVM.currentTab) {
            OutlineView(outlineVM: outlineVM, readerVM: readerVM, document: document)
                .tabItem { Label("目录", systemImage: "list.bullet.indent") }
                .tag(SidebarTab.outline)
                .accessibilityLabel("目录")

            // P-08 新增 Tab
            AnnotationListView(sidebarVM: sidebarVM)
                .tabItem { Label("标注", systemImage: "highlighter") }
                .tag(SidebarTab.annotation)
                .accessibilityLabel("标注")

            BookmarkListView(sidebarVM: sidebarVM)
                .tabItem { Label("书签", systemImage: "bookmark") }
                .tag(SidebarTab.bookmark)
                .accessibilityLabel("书签")

            ThumbnailGridView(document: document, readerVM: readerVM, provider: thumbnailProvider)
                .tabItem { Label("页面", systemImage: "square.grid.2x2") }
                .tag(SidebarTab.thumbnail)
                .accessibilityLabel("页面")
        }
        // UI-Layout-003: 侧栏高度撑满父容器
        .frame(maxHeight: .infinity)
    }
}
