import SwiftUI
import TodoCore

struct TodoRowView: View {
    let todo: TodoItem
    let tag: TodoTag?
    var isSubtask = false
    var isSelected = false
    var isReadOnly = false
    let toggleAction: () -> Void
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName
    private let tagColumnWidth: CGFloat = 34
    private let recurrenceColumnWidth: CGFloat = 30
    private let dateColumnWidth: CGFloat = 108

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 10) {
                Button(action: toggleAction) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(completionForeground)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help(todo.isCompleted ? "Mark Incomplete" : "Mark Complete")
                .disabled(isReadOnly)

                Text(todo.title.isEmpty ? "Untitled Todo" : todo.title)
                    .font(isSubtask ? AppTypography.body(appFontName) : AppTypography.taskRow(appFontName))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(titleForeground)
                    .lineLimit(1)

                Spacer(minLength: 12)

                HStack(spacing: 0) {
                    metadataSlot(width: tagColumnWidth) {
                        if let tag {
                            TodoTagIcon(color: tag.color, width: 28, height: 20)
                                .help(tag.name)
                        }
                    }

                    metadataSlot(width: recurrenceColumnWidth) {
                        if todo.recurrenceSourceID != nil {
                            Image(systemName: "r.circle")
                                .font(AppTypography.body(appFontName))
                                .foregroundStyle(Color.cyan.opacity(0.85))
                                .help("Recurrent")
                        }
                    }

                    metadataSlot(width: dateColumnWidth, alignment: .trailing) {
                        if !scheduleLines.isEmpty {
                            VStack(alignment: .trailing, spacing: 1) {
                                ForEach(scheduleLines, id: \.self) { scheduleLine in
                                    Text(scheduleLine)
                                        .font(AppTypography.taskDate(appFontName))
                                        .foregroundStyle(dueDateForeground)
                                        .lineLimit(1)
                                }
                            }
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .frame(width: tagColumnWidth + recurrenceColumnWidth + dateColumnWidth, alignment: .trailing)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .font(AppTypography.body(appFontName))
        .frame(height: isSubtask ? 40 : 48)
    }

    private var completionForeground: Color {
        if isSelected {
            return .white
        }

        return todo.isCompleted ? .green : .secondary
    }

    private var titleForeground: Color {
        if isSelected {
            return .white
        }

        return todo.isCompleted ? .secondary : .primary
    }

    private var dueDateForeground: Color {
        if isSelected {
            return Color.white.opacity(0.9)
        }

        return todo.isOverdue() ? .red : .secondary
    }

    private var scheduleLines: [String] {
        guard let dueDate = todo.dueDate else {
            return []
        }

        let startText = dueDate.formatted(date: .abbreviated, time: .omitted)

        guard let endDate = todo.endDate,
              !Calendar.current.isDate(endDate, inSameDayAs: dueDate) else {
            return [startText]
        }

        return [startText, endDate.formatted(date: .abbreviated, time: .omitted)]
    }

    private func metadataSlot<Content: View>(
        width: CGFloat,
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            Color.clear
            content()
        }
        .frame(width: width)
    }
}
