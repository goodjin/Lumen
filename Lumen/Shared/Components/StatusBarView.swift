import PDFVeCore
import SwiftUI

/// 底部状态栏：页码、缩放、文件大小、阅读进度
struct StatusBarView: View {
    var readerVM: ReaderViewModel
    var fileURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            // 页码信息
            Text("\(readerVM.currentPage) / \(readerVM.totalPages)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("当前页码")

            // 阅读进度
            if readerVM.totalPages > 0 {
                Text("\(Int(Double(readerVM.currentPage) / Double(readerVM.totalPages) * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("阅读进度")
            }

            Spacer()

            // 文件大小
            if let url = fileURL, let size = fileSize(for: url) {
                Text(size)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("文件大小")
            }

            // 缩放比例
            Text("\(Int(readerVM.zoomLevel * 100))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("缩放比例")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private func fileSize(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return nil }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }
}
