import Foundation

@MainActor
public class BookmarkService {
    private let repository: BookmarkRepository

    public init(repository: BookmarkRepository) {
        self.repository = repository
    }

    // API-063: 切换书签（同一页已有则删除，无则创建）
    public func toggleBookmark(at pageNumber: Int, in documentPath: String) {
        if let existing = try? repository.findByPage(documentPath: documentPath, pageNumber: pageNumber) {
            try? repository.delete(id: existing.id)
        } else {
            let bookmark = BookmarkRecord(documentPath: documentPath, pageNumber: pageNumber)
            try? repository.save(bookmark)
        }
    }

    // API-064: 重命名书签（空字符串时忽略）
    public func renameBookmark(id: UUID, name: String, in documentPath: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? repository.update(id: id, name: trimmed)
    }

    // API-066: 删除书签
    public func deleteBookmark(id: UUID) {
        try? repository.delete(id: id)
    }

    public func bookmarks(for documentPath: String) -> [BookmarkRecord] {
        (try? repository.fetchAll(for: documentPath)) ?? []
    }

    public func isBookmarked(pageNumber: Int, documentPath: String) -> Bool {
        (try? repository.findByPage(documentPath: documentPath, pageNumber: pageNumber)) != nil
    }
}
