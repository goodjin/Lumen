import PDFKit
import Foundation

@MainActor
public class FileService {
    private let docRepo: DocumentRepository

    public init(docRepo: DocumentRepository) {
        self.docRepo = docRepo
    }

    // API-001: 打开文件（校验 + 记录）
    public func openDocument(at url: URL) async throws -> PDFDocument {
        guard url.pathExtension.lowercased() == "pdf" else {
            throw FileError.invalidPDF
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileError.notFound
        }
        guard let doc = PDFDocument(url: url) else {
            throw FileError.invalidPDF
        }
        try docRepo.recordOpen(
            filePath: url.path,
            fileName: url.lastPathComponent,
            pageCount: doc.pageCount
        )
        return doc
    }

    // API-002: 关闭时保存阅读状态（Rule-002）
    public func closeDocument(at url: URL, currentPage: Int, zoomLevel: Double) {
        try? docRepo.updateReadingState(filePath: url.path, page: currentPage, zoom: zoomLevel)
    }

    // API-003: 获取最近文件列表
    public func recentDocuments() -> [DocumentRecord] {
        (try? docRepo.fetchRecent()) ?? []
    }

    // API-004: 打开最近文件（路径校验，Rule-003）
    public func openRecentDocument(_ record: DocumentRecord) async throws -> PDFDocument {
        guard FileManager.default.fileExists(atPath: record.filePath) else {
            try? docRepo.remove(filePath: record.filePath)
            throw FileError.notFoundRemoved
        }
        return try await openDocument(at: URL(fileURLWithPath: record.filePath))
    }

    // API-005: 获取上次阅读状态
    public func readingState(for url: URL) -> (page: Int, zoom: Double)? {
        try? docRepo.readingState(for: url.path)
    }
}
