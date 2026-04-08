import SwiftData
import Foundation

@MainActor
public class BookmarkRepository {
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    /// 保存书签（upsert 语义）
    public func save(_ bookmark: BookmarkRecord) throws {
        let id = bookmark.id
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if try context.fetch(descriptor).first == nil {
            context.insert(bookmark)
        }
        try context.save()
    }

    /// 加载文档所有书签，按页码升序
    public func fetchAll(for documentPath: String) throws -> [BookmarkRecord] {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.documentPath == documentPath },
            sortBy: [SortDescriptor(\.pageNumber)]
        )
        return try context.fetch(descriptor)
    }

    /// 查找指定页的书签（用于切换书签判断）
    public func findByPage(documentPath: String, pageNumber: Int) throws -> BookmarkRecord? {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate {
                $0.documentPath == documentPath && $0.pageNumber == pageNumber
            }
        )
        return try context.fetch(descriptor).first
    }

    /// 删除书签
    public func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }

    /// 重命名书签（空字符串时不更新）
    public func update(id: UUID, name: String) throws {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let record = try context.fetch(descriptor).first {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                record.name = String(trimmed.prefix(50))
            }
            try context.save()
        }
    }
}
