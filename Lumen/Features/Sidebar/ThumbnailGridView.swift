import PDFVeCore
import SwiftUI
import PDFKit

struct ThumbnailGridView: View {
    let document: PDFDocument
    @Bindable var readerVM: ReaderViewModel
    private let provider = ThumbnailProvider()

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 130), spacing: 8)
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        ThumbnailCell(
                            document: document,
                            pageIndex: index,
                            isCurrentPage: readerVM.currentPage == index + 1,
                            provider: provider
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // VIEW-API-005: 缩略图点击跳转
                            let targetPage = index + 1
                            print("[Thumbnail] Tapped page \(targetPage), currentPage: \(readerVM.currentPage)")
                            readerVM.goToPage(targetPage)
                        }
                        .id(index)
                    }
                }
                .padding(8)
            }
            // 当前页高亮并滚动到视图内（AC-013-03）
            .onChange(of: readerVM.currentPage) { _, newPage in
                withAnimation {
                    proxy.scrollTo(newPage - 1, anchor: .center)
                }
            }
        }
    }
}

struct ThumbnailCell: View {
    let document: PDFDocument
    let pageIndex: Int
    let isCurrentPage: Bool
    let provider: ThumbnailProvider

    @State private var image: NSImage? = nil

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // 加载占位（AC-013-05）
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .overlay(
                // 当前页蓝色边框（AC-013-03）
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isCurrentPage ? Color.accentColor : Color.clear,
                            lineWidth: 2)
            )
            .cornerRadius(3)

            Text("\(pageIndex + 1)")
                .font(.caption2)
                .foregroundStyle(isCurrentPage ? Color.accentColor : Color.secondary)
        }
        .task {
            // 进入视口时才加载（LazyVGrid 保证）（AC-013-05）
            guard let page = document.page(at: pageIndex) else { return }
            image = await provider.thumbnail(for: page, pageIndex: pageIndex)
        }
    }
}
