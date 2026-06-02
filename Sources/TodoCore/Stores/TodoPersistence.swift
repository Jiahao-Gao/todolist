import Foundation

public struct TodoPersistenceSnapshot: Codable, Equatable, Sendable {
    public var items: [TodoItem]
    public var recurrentEvents: [TodoItem]
    public var tags: [TodoTag]
    public var trashItems: [TodoItem]

    public init(
        items: [TodoItem] = [],
        recurrentEvents: [TodoItem] = [],
        tags: [TodoTag] = [],
        trashItems: [TodoItem] = []
    ) {
        self.items = items
        self.recurrentEvents = recurrentEvents
        self.tags = tags
        self.trashItems = trashItems
    }

    public var isEmpty: Bool {
        items.isEmpty && recurrentEvents.isEmpty && tags.isEmpty && trashItems.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case recurrentEvents
        case tags
        case trashItems
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        items = try container.decodeIfPresent([TodoItem].self, forKey: .items) ?? []
        recurrentEvents = try container.decodeIfPresent([TodoItem].self, forKey: .recurrentEvents) ?? []
        tags = try container.decodeIfPresent([TodoTag].self, forKey: .tags) ?? []
        trashItems = try container.decodeIfPresent([TodoItem].self, forKey: .trashItems) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(items, forKey: .items)
        try container.encode(recurrentEvents, forKey: .recurrentEvents)
        try container.encode(tags, forKey: .tags)
        try container.encode(trashItems, forKey: .trashItems)
    }
}

public struct TodoPersistence: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupport(appName: String = "TodoList") -> TodoPersistence {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return TodoPersistence(
            fileURL: baseURL
                .appendingPathComponent(appName, isDirectory: true)
                .appendingPathComponent("todos.json")
        )
    }

    public func load() throws -> [TodoItem] {
        try loadSnapshot().items
    }

    public func loadSnapshot() throws -> TodoPersistenceSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return TodoPersistenceSnapshot()
        }

        return try Self.loadSnapshot(from: fileURL)
    }

    public static func loadDemoSnapshot() throws -> TodoPersistenceSnapshot? {
        for url in demoSnapshotCandidateURLs where FileManager.default.fileExists(atPath: url.path) {
            return try loadSnapshot(from: url)
        }

        return nil
    }

    public static func loadSnapshot(from url: URL) throws -> TodoPersistenceSnapshot {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let snapshot = try? decoder.decode(TodoPersistenceSnapshot.self, from: data) {
            return snapshot
        }

        return TodoPersistenceSnapshot(items: try decoder.decode([TodoItem].self, from: data))
    }

    public func save(_ items: [TodoItem]) throws {
        try saveSnapshot(TodoPersistenceSnapshot(items: items))
    }

    public func saveSnapshot(_ snapshot: TodoPersistenceSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var demoSnapshotCandidateURLs: [URL] {
        var urls: [URL] = []

        if let bundledURL = Bundle.main.url(forResource: "todos", withExtension: "json") {
            urls.append(bundledURL)
        }

        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(currentDirectoryURL.appendingPathComponent("todos.json"))

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let packageRootURL = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        urls.append(packageRootURL.appendingPathComponent("todos.json"))

        return urls
    }
}
