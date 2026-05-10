import PDFVeCore
import SwiftUI
import PDFKit
import os.log

private let logger = Logger(subsystem: "com.pdfve", category: "OutlineView")

struct OutlineView: View {
    @Bindable var outlineVM: OutlineViewModel
    var readerVM: ReaderViewModel
    var document: PDFDocument

    var body: some View {
        Group {
            if !outlineVM.hasOutline {
                // Fallback: 显示页面导航
                PageNavigationView(document: document, readerVM: readerVM)
            } else {
                // 原有目录结构
                let currentId = outlineVM.currentItemId(forPage: readerVM.currentPage)
                List(outlineVM.items, children: \.childrenIfAny) { item in
                    Button(action: {
                        outlineVM.selectItem(item, readerVM: readerVM)
                    }) {
                        OutlineItemRow(item: item, isCurrent: item.id == currentId)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct OutlineItemRow: View {
    let item: OutlineItem
    var isCurrent: Bool = false

    var body: some View {
        HStack {
            Text(item.title)
                .lineLimit(2)
                .fontWeight(isCurrent ? .semibold : .regular)
            Spacer()
            Text("\(item.pageNumber)")
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .font(.caption)
                .fontWeight(isCurrent ? .semibold : .regular)
        }
        .padding(.leading, CGFloat((item.depth - 1) * 12))
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isCurrent ? Color.accentColor.opacity(0.3) : Color.clear)
        )
    }
}

// children 为空时返回 nil，让 List 不显示展开箭头
extension OutlineItem {
    var childrenIfAny: [OutlineItem]? {
        children.isEmpty ? nil : children
    }
}
