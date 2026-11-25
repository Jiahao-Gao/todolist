import Foundation

public struct TodoTag: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: TodoTagColor
    public var order: Int

    public init(
        id: UUID = UUID(),
        name: String,
        color: TodoTagColor = .blue,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.order = order
    }
}

public enum TodoTagColor: String, CaseIterable, Codable, Equatable, Sendable {
    case red
    case orange
    case yellow
    case green
    case mint
    case blue
    case purple
    case gray

    public var title: String {
        switch self {
        case .red:
            "Red"
        case .orange:
            "Orange"
        case .yellow:
            "Yellow"
        case .green:
            "Green"
        case .mint:
            "Mint"
        case .blue:
            "Blue"
        case .purple:
            "Purple"
        case .gray:
            "Gray"
        }
    }
}
