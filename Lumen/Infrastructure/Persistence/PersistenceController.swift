import SwiftData
import Foundation

@MainActor
public class PersistenceController {
    public static let shared = PersistenceController()

    public let container: ModelContainer

    public init() {
        let schema = Schema([
            DocumentRecord.self,
            AnnotationRecord.self,
            BookmarkRecord.self
        ])

        // 存储路径：~/Library/Application Support/Lumen/Lumen.store
        guard let appSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Cannot access Application Support directory")
        }

        let storeDir = appSupportURL.appendingPathComponent("Lumen")
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appendingPathComponent("Lumen.store")
        let config = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // 测试用：内存数据库
    public static func makeInMemory() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }

    private init(inMemory: Bool) {
        let schema = Schema([DocumentRecord.self, AnnotationRecord.self, BookmarkRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
    }
}
