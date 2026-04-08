import SwiftData
import Foundation

@MainActor
public class AnnotationRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // API-050: 保存标注（upsert：存在则更新，否则插入）
    public func save(_ annotation: AnnotationRecord) throws {
        let id = annotation.id
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.content = annotation.content
            existing.colorHex = annotation.colorHex
            existing.boundsX = annotation.boundsX
            existing.boundsY = annotation.boundsY
            existing.boundsWidth = annotation.boundsWidth
            existing.boundsHeight = annotation.boundsHeight
            existing.drawingPathData = annotation.drawingPathData
        } else {
            context.insert(annotation)
        }
        try context.save()
    }

    // API-051: 加载文档所有标注（按页码升序，静默失败返回空数组）
    public func fetchAll(for documentPath: String) throws -> [AnnotationRecord] {
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.documentPath == documentPath },
            sortBy: [SortDescriptor(\.pageNumber), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    // API-052: 删除标注
    public func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try context.fetch(descriptor).first else { return }
        context.delete(record)
        try context.save()
    }

    // 删除文档所有标注
    public func deleteAll(for documentPath: String) throws {
        let records = (try? fetchAll(for: documentPath)) ?? []
        records.forEach { context.delete($0) }
        try context.save()
    }
}
