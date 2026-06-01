import SwiftUI
import TodoCore

struct TodoRowView: View {
    let todo: TodoItem
    var isSubtask = false
    var isSelected = false
    let toggleAction: () -> Void
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: toggleAction) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(completionForeground)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help(todo.isCompleted ? "Mark Incomplete" : "Mark Complete")

            Text(todo.title.isEmpty ? "Untitled Todo" : todo.title)
                .font(isSubtask ? AppTypography.body(appFontName) : AppTypography.taskRow(appFontName))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(titleForeground)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let scheduleText {
                Text(scheduleText)
                    .font(AppTypography.taskDate(appFontName))
                    .foregroundStyle(dueDateForeground)
                    .lineLimit(1)
            }
        }
        .font(AppTypography.body(appFontName))
        .frame(height: isSubtask ? 26 : 36)
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

    private var scheduleText: String? {
        guard let dueDate = todo.dueDate else {
            return nil
        }

        let startText = dueDate.formatted(date: .abbreviated, time: .omitted)

        guard let endDate = todo.endDate,
              !Calendar.current.isDate(endDate, inSameDayAs: dueDate) else {
            return startText
        }

        return "\(startText) - \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }
}
