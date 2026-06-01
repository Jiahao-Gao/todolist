import Foundation

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
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([TodoItem].self, from: data)
    }

    public func save(_ items: [TodoItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
