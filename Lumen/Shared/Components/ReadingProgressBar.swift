import SwiftUI

/// 阅读进度条：显示在 PDF 区域底部的细长进度指示
struct ReadingProgressBar: View {
    var progress: Double  // 0.0 ~ 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 3)
    }
}
