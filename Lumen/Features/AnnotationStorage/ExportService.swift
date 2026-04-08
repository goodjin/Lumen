import Foundation

@MainActor
public class ExportService {
    private let annotationRepo: AnnotationRepository

    public init(annotationRepo: AnnotationRepository) {
        self.annotationRepo = annotationRepo
    }

    // API-053: 导出为文本（AC-016-01, AC-016-03）
    public func exportAnnotationsAsText(for documentPath: String) -> String {
        let annotations = (try? annotationRepo.fetchAll(for: documentPath)) ?? []
        guard !annotations.isEmpty else { return "" }

        return annotations.map { ann in
            let typeLabel = ann.annotationType.exportLabel
            let content: String
            switch ann.annotationType {
            case .drawing:
                content = "手绘标记"
            case .note:
                content = ann.content ?? ""
            default:
                content = ann.selectedText ?? ann.content ?? ""
            }
            return "[第\(ann.pageNumber)页] [\(typeLabel)] \(content)"
        }.joined(separator: "\n")
    }

    // 导出并保存为 .txt 文件
    public func exportToFile(for documentPath: String, saveTo url: URL) throws {
        let text = exportAnnotationsAsText(for: documentPath)
        guard !text.isEmpty else {
            throw ExportError.noAnnotations
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

public enum ExportError: LocalizedError {
    case noAnnotations
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .noAnnotations:    return "当前文档无标注内容"
        case .permissionDenied: return "没有写入权限，请选择其他位置"
        }
    }
}
