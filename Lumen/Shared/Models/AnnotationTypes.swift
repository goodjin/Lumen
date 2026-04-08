import Foundation

public enum AnnotationType: String, Codable, CaseIterable {
    case highlight      = "highlight"
    case underline      = "underline"
    case strikethrough  = "strikethrough"
    case note           = "note"
    case drawing        = "drawing"

    public var displayName: String {
        switch self {
        case .highlight:     return "高亮"
        case .underline:     return "下划线"
        case .strikethrough: return "删除线"
        case .note:          return "注释"
        case .drawing:       return "绘制"
        }
    }

    public var systemImage: String {
        switch self {
        case .highlight:     return "highlighter"
        case .underline:     return "underline"
        case .strikethrough: return "strikethrough"
        case .note:          return "note.text"
        case .drawing:       return "pencil.tip"
        }
    }

    public var exportLabel: String {
        switch self {
        case .highlight:     return "高亮"
        case .underline:     return "下划线"
        case .strikethrough: return "删除线"
        case .note:          return "注释"
        case .drawing:       return "绘制"
        }
    }
}

public enum AnnotationColor: String, CaseIterable, Codable {
    case yellow  = "#FFFF00"
    case green   = "#52C41A"
    case blue    = "#1890FF"
    case pink    = "#FF69B4"
    case orange  = "#FA8C16"
    case red     = "#FF4D4F"
    case black   = "#000000"
}

public enum DrawingLineWidth: Double, CaseIterable, Codable {
    case thin   = 1.5
    case medium = 3.0
    case thick  = 6.0
}

public enum AnnotationTool: Equatable {
    case none
    case highlight(color: AnnotationColor)
    case underline(color: AnnotationColor)
    case strikethrough(color: AnnotationColor)
    case note
    case drawing(color: AnnotationColor, lineWidth: DrawingLineWidth)
    case eraser
}
