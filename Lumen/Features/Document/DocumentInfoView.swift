import SwiftUI
import PDFKit

/// 文档属性面板：显示 PDF 元数据
struct DocumentInfoView: View {
    let document: PDFDocument
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("文档属性")
                    .font(.headline)
                    .accessibilityLabel("文档属性")
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoSection("基本信息") {
                        infoRow("文件名", fileURL.lastPathComponent)
                        infoRow("页面数", "\(document.pageCount)")
                        if let size = fileSize() {
                            infoRow("文件大小", size)
                        }
                        infoRow("加密", document.isEncrypted ? "是" : "否")
                        infoRow("允许复制", document.allowsCopying ? "是" : "否")
                        infoRow("允许打印", document.allowsPrinting ? "是" : "否")
                    }

                    infoSection("元数据") {
                        let attrs = document.documentAttributes ?? [:]
                        if let title = attrs["Title"] as? String, !title.isEmpty {
                            infoRow("标题", title)
                        }
                        if let author = attrs["Author"] as? String, !author.isEmpty {
                            infoRow("作者", author)
                        }
                        if let subject = attrs["Subject"] as? String, !subject.isEmpty {
                            infoRow("主题", subject)
                        }
                        if let creator = attrs["Creator"] as? String, !creator.isEmpty {
                            infoRow("创建工具", creator)
                        }
                        if let creationDate = attrs["CreationDate"] as? Date {
                            infoRow("创建日期", creationDate.formatted(.dateTime))
                        }
                        if let modDate = attrs["ModDate"] as? Date {
                            infoRow("修改日期", modDate.formatted(.dateTime))
                        }
                        if let keywords = attrs["Keywords"] as? [String], !keywords.isEmpty {
                            infoRow("关键词", keywords.joined(separator: ", "))
                        }
                    }

                    infoSection("文件路径") {
                        Text(fileURL.path)
                            .font(.caption)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("文件路径: \(fileURL.path)")
                    }
                }
                .padding()
            }
        }
        .frame(width: 360, height: 480)
    }

    @ViewBuilder
    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .accessibilityLabel(title)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
        }
        .accessibilityLabel("\(label): \(value)")
    }

    private func fileSize() -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else { return nil }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.2f MB", Double(size) / (1024 * 1024))
    }
}
