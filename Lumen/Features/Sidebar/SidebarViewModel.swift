import PDFKit
import SwiftUI

@MainActor
@Observable
public class SidebarViewModel {
    private let bookmarkService: BookmarkService
    public var readerVM: ReaderViewModel
    public var annotationVM: AnnotationViewModel

    public var bookmarks: [BookmarkRecord] = []
    public var annotationFilter: AnnotationType? = nil  // nil = 全部

    public var documentPath: String = ""

    // 当前选中的标签页（用于状态记忆）
    public var currentTab: SidebarTab = .outline {
        didSet {
            WindowStateManager.shared.lastSidebarTab = currentTab
        }
    }

    public init(bookmarkService: BookmarkService,
         readerVM: ReaderViewModel,
         annotationVM: AnnotationViewModel) {
        self.bookmarkService = bookmarkService
        self.readerVM = readerVM
        self.annotationVM = annotationVM

        // 恢复上次选中的标签页
        self.currentTab = WindowStateManager.shared.lastSidebarTab
    }

    public func loadForDocument(_ path: String) {
        documentPath = path
        refreshBookmarks()
    }

    public func refreshBookmarks() {
        bookmarks = bookmarkService.bookmarks(for: documentPath)
    }

    // API-061: 筛选标注
    public func filteredAnnotations() -> [AnnotationRecord] {
        guard let filter = annotationFilter else {
            return annotationVM.annotations
        }
        return annotationVM.annotations.filter { $0.annotationType == filter }
    }

    // API-062: 点击标注跳转
    public func selectAnnotation(_ annotation: AnnotationRecord) {
        readerVM.goToPage(annotation.pageNumber)
    }

    // API-065: 点击书签跳转
    public func selectBookmark(_ bookmark: BookmarkRecord) {
        readerVM.goToPage(bookmark.pageNumber)
    }

    // API-063: 切换书签
    public func toggleBookmark() {
        bookmarkService.toggleBookmark(at: readerVM.currentPage, in: documentPath)
        refreshBookmarks()
    }

    // API-064: 重命名
    public func renameBookmark(id: UUID, name: String) {
        bookmarkService.renameBookmark(id: id, name: name, in: documentPath)
        refreshBookmarks()
    }

    // API-066: 删除书签
    public func deleteBookmark(id: UUID) {
        bookmarkService.deleteBookmark(id: id)
        refreshBookmarks()
    }

    public var isCurrentPageBookmarked: Bool {
        bookmarkService.isBookmarked(pageNumber: readerVM.currentPage,
                                     documentPath: documentPath)
    }
}
