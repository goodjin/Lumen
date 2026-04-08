import PDFVeCore
import SwiftUI
import PDFKit

struct SearchBarView: View {
    @Bindable var searchVM: SearchViewModel
    var document: PDFDocument

    var body: some View {
        HStack(spacing: 6) {
            // 搜索输入框
            TextField("搜索…", text: $searchVM.keyword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                // 无结果时背景变红（AC-005-07）
                .background(searchVM.hasNoResults ? Color.red.opacity(0.3) : Color.clear)
                .cornerRadius(4)
                .onSubmit { searchVM.nextMatch() }          // Enter 下一个（AC-005-04）
                .onChange(of: searchVM.keyword) {
                    searchVM.performSearch(in: document)
                }

            // 结果数量（AC-005-03）
            if !searchVM.resultSummary.isEmpty {
                Text(searchVM.resultSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
            }

            // 无可搜索文本提示（BOUND-051）
            if searchVM.isUnsearchable {
                Text("此文档不含可搜索文本")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // 上一个 / 下一个
            Button(action: { searchVM.previousMatch() }) {
                Image(systemName: "chevron.up")
            }
            .disabled(searchVM.results.isEmpty)

            Button(action: { searchVM.nextMatch() }) {
                Image(systemName: "chevron.down")
            }
            .disabled(searchVM.results.isEmpty)

            // 大小写开关（AC-005-06）
            Toggle("Aa", isOn: $searchVM.caseSensitive)
                .toggleStyle(.button)
                .onChange(of: searchVM.caseSensitive) {
                    searchVM.performSearch(in: document)
                }

            // 关闭按钮（AC-005-08）
            Button(action: { searchVM.dismissSearch() }) {
                Image(systemName: "xmark")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
        // Esc 关闭（AC-005-08）
        .onKeyPress(.escape) { searchVM.dismissSearch(); return .handled }
    }
}
