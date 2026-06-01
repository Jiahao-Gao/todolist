import Foundation

public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var dueDate: Date?
    public var subtasks: [TodoItem]

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        subtasks: [TodoItem] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.subtasks = subtasks
    }

    public func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return true
        }

        return title.localizedCaseInsensitiveContains(query)
            || notes.localizedCaseInsensitiveContains(query)
            || subtasks.contains { $0.matches(searchText: query) }
    }

    public func isDueToday(referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate else {
            return false
        }

        return calendar.isDate(dueDate, inSameDayAs: referenceDate)
    }

    public func isOverdue(referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate, !isCompleted else {
            return false
        }

        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: referenceDate)
    }
}

extension TodoItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case isCompleted
        case dueDate
        case subtasks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        subtasks = try container.decodeIfPresent([TodoItem].self, forKey: .subtasks) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(subtasks, forKey: .subtasks)
    }
}
