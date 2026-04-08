import Foundation

public enum FileError: LocalizedError {
    case notFound
    case notFoundRemoved  // 从最近文件列表找不到，已自动移除
    case invalidPDF

    public var errorDescription: String? {
        switch self {
        case .notFound:        return "文件不存在或已被移动"
        case .notFoundRemoved: return "文件已不存在，已从最近文件列表中移除"
        case .invalidPDF:      return "这不是有效的 PDF 文档"
        }
    }
}
