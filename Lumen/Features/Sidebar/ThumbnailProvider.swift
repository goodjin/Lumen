import PDFKit
import AppKit

public actor ThumbnailProvider {
    public init() {}
    private var cache: [Int: NSImage] = [:]  // pageIndex → NSImage
    private let thumbnailSize = CGSize(width: 120, height: 160)

    // API-067: 异步生成缩略图（AC-013-05 按需加载）
    public func thumbnail(for page: PDFPage, pageIndex: Int) async -> NSImage {
        if let cached = cache[pageIndex] { return cached }
        let image = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        cache[pageIndex] = image
        return image
    }

    public func clearCache() {
        cache.removeAll()
    }
}
