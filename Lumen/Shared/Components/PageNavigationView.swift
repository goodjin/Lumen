import PDFVeCore
import SwiftUI
import PDFKit

/// 页面导航视图 - 当 PDF 无目录时显示页面列表
struct PageNavigationView: View {
    let document: PDFDocument
    var readerVM: ReaderViewModel

    private var pageRange: [Int] {
        Array(1...document.pageCount)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(pageRange, id: \.self) { pageNumber in
                    PageNavigationRow(
                        pageNumber: pageNumber,
                        isCurrentPage: readerVM.currentPage == pageNumber
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        readerVM.goToPage(pageNumber)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 页面导航行
struct PageNavigationRow: View {
    let pageNumber: Int
    let isCurrentPage: Bool

    var body: some View {
        HStack {
            Image(systemName: "doc")
                .foregroundStyle(isCurrentPage ? Color.accentColor : Color.secondary)
                .frame(width: 20)
            Text("第 \(pageNumber) 页")
                .font(.body)
                .foregroundStyle(isCurrentPage ? .primary : .secondary)
            Spacer()
            if isCurrentPage {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrentPage ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
