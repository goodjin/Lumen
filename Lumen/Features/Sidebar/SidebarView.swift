import PDFVeCore
import SwiftUI
import PDFKit

struct SidebarView: View {
    @Bindable var outlineVM: OutlineViewModel
    @Bindable var sidebarVM: SidebarViewModel
    var readerVM: ReaderViewModel
    var document: PDFDocument

    var body: some View {
        TabView(selection: $sidebarVM.currentTab) {
            OutlineView(outlineVM: outlineVM, readerVM: readerVM, document: document)
                .tabItem { Label("目录", systemImage: "list.bullet.indent") }
                .tag(SidebarTab.outline)

            // P-08 新增 Tab
            AnnotationListView(sidebarVM: sidebarVM)
                .tabItem { Label("标注", systemImage: "highlighter") }
                .tag(SidebarTab.annotation)

            BookmarkListView(sidebarVM: sidebarVM)
                .tabItem { Label("书签", systemImage: "bookmark") }
                .tag(SidebarTab.bookmark)

            ThumbnailGridView(document: document, readerVM: readerVM)
                .tabItem { Label("页面", systemImage: "square.grid.2x2") }
                .tag(SidebarTab.thumbnail)
        }
        // UI-Layout-003: 侧栏高度撑满父容器
        .frame(maxHeight: .infinity)
    }
}
