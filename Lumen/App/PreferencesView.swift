import PDFVeCore
import SwiftUI

struct PreferencesView: View {
    @Binding var isPresented: Bool
    @State private var autoReopenLastDocument: Bool = WindowStateManager.shared.autoReopenLastDocument
    @State private var defaultReadingMode: ReaderViewModel.ReadingMode = WindowStateManager.shared.defaultReadingMode
    @State private var defaultDisplayMode: ReaderViewModel.DisplayMode = WindowStateManager.shared.defaultDisplayMode

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("偏好设置")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding()

            Divider()

            Form {
                Section {
                    Toggle("启动时自动打开上次文档", isOn: $autoReopenLastDocument)
                        .onChange(of: autoReopenLastDocument) { _, newValue in
                            WindowStateManager.shared.autoReopenLastDocument = newValue
                        }
                        .accessibilityLabel("启动时自动打开上次文档")
                } header: {
                    Text("常规")
                }

                Section {
                    Picker("阅读模式", selection: $defaultReadingMode) {
                        ForEach(ReaderViewModel.ReadingMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: defaultReadingMode) { _, newValue in
                        WindowStateManager.shared.defaultReadingMode = newValue
                    }
                    .accessibilityLabel("阅读模式")

                    Picker("显示模式", selection: $defaultDisplayMode) {
                        ForEach(ReaderViewModel.DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: defaultDisplayMode) { _, newValue in
                        WindowStateManager.shared.defaultDisplayMode = newValue
                    }
                    .accessibilityLabel("显示模式")
                } header: {
                    Text("阅读")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 400, height: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
