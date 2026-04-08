import SwiftUI

/// 便签展开弹出视图（STATE-005：折叠/展开）
struct NotePopoverView: View {
    @Bindable var annotationVM: AnnotationViewModel
    let record: AnnotationRecord
    @State private var content: String
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero

    init(annotationVM: AnnotationViewModel, record: AnnotationRecord) {
        self.annotationVM = annotationVM
        self.record = record
        self._content = State(initialValue: record.content ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏（可拖动，AC-009-04）
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.yellow)
                Spacer()
                // 删除按钮（AC-009-08）
                Button {
                    annotationVM.deleteAnnotation(id: record.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.8))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                        isDragging = true
                    }
                    .onEnded { value in
                        let newBounds = CGRect(
                            x: record.boundsX + value.translation.width,
                            y: record.boundsY + value.translation.height,
                            width: record.boundsWidth,
                            height: record.boundsHeight
                        )
                        annotationVM.updateNote(record, bounds: newBounds)
                        dragOffset = .zero
                        isDragging = false
                    }
            )

            // 文本编辑区
            TextEditor(text: $content)
                .font(.body)
                .padding(4)
                .frame(minHeight: 80)
                .onChange(of: content) {
                    annotationVM.updateNote(record, content: content)
                }
        }
        .frame(width: 200)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(radius: 4)
        .offset(dragOffset)
    }
}
