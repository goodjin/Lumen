import PDFVeCore
import SwiftUI

struct AnnotationListView: View {
    @Bindable var sidebarVM: SidebarViewModel
    @State private var items: [AnnotationRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            // 类型筛选器（AC-011-05）
            filterBar

            Divider()

            if items.isEmpty {
                // 空状态（AC-011-06）
                ContentUnavailableView(
                    sidebarVM.annotationFilter == nil ? "暂无标注" : "该类型暂无标注",
                    systemImage: "highlighter"
                )
            } else {
                List(items, id: \.id) { annotation in
                    AnnotationRow(annotation: annotation)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("[AnnotationList] Tapped annotation at page \(annotation.pageNumber)")
                            sidebarVM.selectAnnotation(annotation)
                        }
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear { items = sidebarVM.filteredAnnotations() }
        .onChange(of: sidebarVM.annotationFilter) { _, _ in
            items = sidebarVM.filteredAnnotations()
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(title: "全部", isSelected: sidebarVM.annotationFilter == nil) {
                    sidebarVM.annotationFilter = nil
                }
                ForEach(AnnotationType.allCases, id: \.self) { type in
                    FilterChip(title: type.displayName,
                               isSelected: sidebarVM.annotationFilter == type) {
                        sidebarVM.annotationFilter = sidebarVM.annotationFilter == type ? nil : type
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

struct AnnotationRow: View {
    let annotation: AnnotationRecord

    var body: some View {
        HStack(spacing: 8) {
            // 类型颜色指示条
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: annotation.colorHex) ?? .yellow)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(annotation.annotationType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("第\(annotation.pageNumber)页")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let content = annotation.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .lineLimit(2)
                } else if let selectedText = annotation.selectedText, !selectedText.isEmpty {
                    Text(selectedText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
