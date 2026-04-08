import PDFVeCore
import SwiftUI

struct RecentFilesView: View {
    @Environment(DocumentViewModel.self) var docVM
    @State private var openingFilePath: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 标题区
            HStack {
                Text("PDF-Ve")
                    .font(.largeTitle.bold())
                Spacer()
                Button("打开文件…") {
                    Task { await docVM.showOpenPanel() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if docVM.recentDocuments.isEmpty {
                // 空状态
                ContentUnavailableView("没有最近打开的文件",
                    systemImage: "doc.text",
                    description: Text("点击「打开文件」选择 PDF"))
            } else {
                // 最近文件列表（AC-015-01）
                List(docVM.recentDocuments, id: \.filePath) { record in
                    RecentFileRow(
                        record: record,
                        isOpening: openingFilePath == record.filePath
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard openingFilePath == nil else { return }
                        openingFilePath = record.filePath
                        Task {
                            await docVM.openRecent(record)
                            openingFilePath = nil
                        }
                    }
                }
            }
        }
        // 拖拽打开（AC-001-02）
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "pdf" else { return }
            Task { @MainActor in await docVM.open(url: url) }
        }
        return true
    }
}

struct RecentFileRow: View {
    let record: DocumentRecord
    let isOpening: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 文件图标
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Text(record.filePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(record.lastOpenedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // 加载指示器或箭头
            if isOpening {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .cursor(.pointingHand)
    }
}

// 鼠标指针扩展
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovered in
            if isHovered {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
