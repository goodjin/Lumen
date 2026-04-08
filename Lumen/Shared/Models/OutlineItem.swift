import Foundation

public struct OutlineItem: Identifiable {
    public let id: UUID
    public let title: String
    public let pageNumber: Int
    public let depth: Int               // 1~5
    public var children: [OutlineItem]
    public var isExpanded: Bool = true

    public init(title: String, pageNumber: Int, depth: Int, children: [OutlineItem] = []) {
        self.id = UUID()
        self.title = title
        self.pageNumber = pageNumber
        self.depth = depth
        self.children = children
    }
}
