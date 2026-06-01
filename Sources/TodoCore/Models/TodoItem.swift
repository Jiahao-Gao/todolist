import Foundation

public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var dueDate: Date?
    public var endDate: Date?
    public var order: Int
    public var subtasks: [TodoItem]

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        endDate: Date? = nil,
        order: Int = 0,
        subtasks: [TodoItem] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.endDate = endDate
        self.order = order
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

        let startDay = calendar.startOfDay(for: dueDate)
        let endDay = calendar.startOfDay(for: endDate ?? dueDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let rangeStart = min(startDay, endDay)
        let rangeEnd = max(startDay, endDay)

        return rangeStart <= referenceDay && referenceDay <= rangeEnd
    }

    public func isUpcoming(referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate,
              let windowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)),
              let windowEnd = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: referenceDate)) else {
            return false
        }

        let dueDay = calendar.startOfDay(for: dueDate)

        return dueDay >= windowStart && dueDay <= windowEnd
    }

    public func isOverdue(referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate, !isCompleted else {
            return false
        }

        let overdueDate = endDate ?? dueDate

        return calendar.startOfDay(for: overdueDate) < calendar.startOfDay(for: referenceDate)
    }
}

extension TodoItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case isCompleted
        case dueDate
        case endDate
        case order
        case subtasks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        subtasks = try container.decodeIfPresent([TodoItem].self, forKey: .subtasks) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(order, forKey: .order)
        try container.encode(subtasks, forKey: .subtasks)
    }
}
