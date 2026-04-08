import PDFVeCore
import SwiftUI

struct BookmarkListView: View {
    @Bindable var sidebarVM: SidebarViewModel
    @State private var editingBookmarkId: UUID? = nil
    @State private var editingName: String = ""

    var body: some View {
        Group {
            if sidebarVM.bookmarks.isEmpty {
                ContentUnavailableView("暂无书签",
                    systemImage: "bookmark",
                    description: Text("按 ⌘B 在当前页添加书签"))
            } else {
                List {
                    ForEach(sidebarVM.bookmarks, id: \.id) { bookmark in
                        bookmarkRow(bookmark)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private func bookmarkRow(_ bookmark: BookmarkRecord) -> some View {
        HStack {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.orange)

            if editingBookmarkId == bookmark.id {
                // 重命名输入框（AC-012-04）
                TextField("书签名称", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sidebarVM.renameBookmark(id: bookmark.id, name: editingName)
                        editingBookmarkId = nil
                    }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.name)
                        .lineLimit(1)
                    Text("第\(bookmark.pageNumber)页")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // 点击跳转（AC-012-05）
                    sidebarVM.selectBookmark(bookmark)
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { _ in
                        // 双击重命名（AC-012-04）
                        editingBookmarkId = bookmark.id
                        editingName = bookmark.name
                    }
                )
            }

            Spacer()
        }
        .contextMenu {
            Button("重命名") {
                editingBookmarkId = bookmark.id
                editingName = bookmark.name
            }
            Divider()
            Button("删除书签", role: .destructive) {
                sidebarVM.deleteBookmark(id: bookmark.id)
            }
        }
    }
}
