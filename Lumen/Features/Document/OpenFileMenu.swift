import SwiftUI
import PDFKit
import PDFVeCore

struct OpenFileMenu: View {
    @Environment(DocumentViewModel.self) var docVM
    @State private var showNetworkDialog = false
    @State private var networkURL = ""
    @State private var showError = false
    @State private var errorMessage = ""

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
                    if let url = URL(string: networkURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                       url.scheme == "http" || url.scheme == "https" {
                        await openNetworkFile(url: url)
                    } else {
                        errorMessage = "URL 格式无效，请输入以 http:// 或 https:// 开头的有效地址。"
                        showError = true
                    }
                    networkURL = ""
                }
            }
        } message: {
            Text("请输入 PDF 文件的 URL 地址")
        }
        .alert("打开失败", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func openNetworkFile(url: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // 检查 HTTP 状态码
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    errorMessage = "服务器返回错误（HTTP \(httpResponse.statusCode)）。请检查 URL 是否正确。"
                    showError = true
                    return
                }
                // 检查 Content-Type 是否为 PDF
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   !contentType.lowercased().contains("pdf") {
                    errorMessage = "该 URL 返回的不是 PDF 文件（Content-Type: \(contentType)）。"
                    showError = true
                    return
                }
            }

            // 尝试解析为 PDF
            guard PDFDocument(data: data) != nil else {
                errorMessage = "下载的数据不是有效的 PDF 文件，请检查 URL 是否指向 PDF 文档。"
                showError = true
                return
            }

            // 创建临时文件
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)
            try data.write(to: tempURL)
            await docVM.open(url: tempURL)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "无法连接到网络，请检查网络连接。"
            case .cannotFindHost:
                errorMessage = "无法找到服务器（\(url.host ?? "未知")），请检查 URL 是否正确。"
            case .timedOut:
                errorMessage = "连接超时，请稍后重试或检查网络连接。"
            case .cannotConnectToHost:
                errorMessage = "无法连接到服务器，请检查 URL 是否正确。"
            case .badServerResponse:
                errorMessage = "服务器响应无效，请稍后重试。"
            default:
                errorMessage = "网络请求失败：\(urlError.localizedDescription)"
            }
            showError = true
        } catch {
            errorMessage = "打开网络文件失败：\(error.localizedDescription)"
            showError = true
        }
    }
}