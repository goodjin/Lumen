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
                List(outlineVM.items, children: \.childrenIfAny) { item in
                    Button(action: {
                        outlineVM.selectItem(item, readerVM: readerVM)
                    }) {
                        OutlineItemRow(item: item)
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
    var body: some View {
        HStack {
            Text(item.title)
                .lineLimit(2)
            Spacer()
            Text("\(item.pageNumber)")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.leading, CGFloat((item.depth - 1) * 12))
    }
}

// children 为空时返回 nil，让 List 不显示展开箭头
extension OutlineItem {
    var childrenIfAny: [OutlineItem]? {
        children.isEmpty ? nil : children
    }
}
