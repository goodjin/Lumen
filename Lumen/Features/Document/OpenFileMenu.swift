import SwiftUI
import PDFKit
import PDFVeCore

struct OpenFileMenu: View {
    @Environment(DocumentViewModel.self) var docVM
    @State private var showNetworkDialog = false
    @State private var networkURL = ""

    var body: some View {
        Menu {
            // 打开文件
            Button(action: {
                Task { await docVM.showOpenPanel() }
            }) {
                Label("打开文件...", systemImage: "doc.badge.plus")
            }

            // 打开网络文件
            Button(action: {
                showNetworkDialog = true
            }) {
                Label("打开网络文件...", systemImage: "globe")
            }

            Divider()

            // 最近文件
            if !docVM.recentDocuments.isEmpty {
                Menu("最近文件") {
                    ForEach(docVM.recentDocuments.prefix(5), id: \.filePath) { record in
                        Button(action: {
                            Task { await docVM.openRecent(record) }
                        }) {
                            Text(record.fileName)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                Text("无最近文件")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 16))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28, height: 28)
        .alert("打开网络文件", isPresented: $showNetworkDialog) {
            TextField("输入 PDF URL", text: $networkURL)
            Button("取消", role: .cancel) {
                networkURL = ""
            }
            Button("打开") {
                Task {
                    if let url = URL(string: networkURL) {
                        await openNetworkFile(url: url)
                    }
                    networkURL = ""
                }
            }
        } message: {
            Text("请输入 PDF 文件的 URL 地址")
        }
    }

    private func openNetworkFile(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let doc = PDFDocument(data: data) {
                // 创建临时文件
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try data.write(to: tempURL)
                await docVM.open(url: tempURL)
            }
        } catch {
            print("打开网络文件失败: \(error)")
        }
    }
}