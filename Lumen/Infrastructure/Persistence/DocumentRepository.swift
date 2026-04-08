import SwiftData
import Foundation

@MainActor
public class DocumentRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// 记录文件打开（新增或更新 lastOpenedAt）
    public func recordOpen(filePath: String, fileName: String, pageCount: Int) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.lastOpenedAt = Date()
            existing.pageCount = pageCount
        } else {
            let record = DocumentRecord(filePath: filePath, fileName: fileName, pageCount: pageCount)
            context.insert(record)
            try enforceMaxCount()
        }
        try context.save()
    }

    /// 最多保留20条，删除最旧的（Rule-004）
    private func enforceMaxCount() throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        if all.count > 20 {
            for record in all[20...] {
                context.delete(record)
            }
        }
    }

    /// 按 lastOpenedAt 降序返回最多20条
    public func fetchRecent() throws -> [DocumentRecord] {
        var descriptor = FetchDescriptor<DocumentRecord>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        return try context.fetch(descriptor)
    }

    /// 更新阅读状态（Rule-002）
    public func updateReadingState(filePath: String, page: Int, zoom: Double) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        if let record = try context.fetch(descriptor).first {
            record.lastViewedPage = page
            record.zoomLevel = zoom
            try context.save()
        }
    }

    /// 删除记录（文件失效时，Rule-003）
    public func remove(filePath: String) throws {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }

    /// 获取阅读状态（上次页码和缩放）
    public func readingState(for filePath: String) throws -> (page: Int, zoom: Double)? {
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        guard let record = try context.fetch(descriptor).first else { return nil }
        return (page: record.lastViewedPage, zoom: record.zoomLevel)
    }
}
