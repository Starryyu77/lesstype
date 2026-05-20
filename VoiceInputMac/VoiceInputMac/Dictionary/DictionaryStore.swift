import Foundation

final class DictionaryStore {
    private let database: AppDatabase
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(database: AppDatabase) {
        self.database = database
    }

    func seedDefaultsIfNeeded() throws {
        let count = try database.query("SELECT COUNT(*) AS count FROM dictionary_entries").first?["count"] ?? "0"
        if count == "0" {
            for entry in Self.defaultEntries {
                try insert(entry)
            }
            return
        }

        for entry in Self.defaultEntries where try isMissingDefault(entry) {
            try insert(entry)
        }
    }

    func fetchAll() throws -> [DictionaryEntry] {
        let rows = try database.query("SELECT * FROM dictionary_entries ORDER BY priority DESC, id ASC")
        return rows.map { row in
            DictionaryEntry(
                id: Int(row["id"] ?? ""),
                spoken: row["spoken"] ?? "",
                written: row["written"] ?? "",
                aliases: Self.decodeAliases(row["aliases"] ?? ""),
                scope: row["scope"] ?? "global",
                priority: Int(row["priority"] ?? "") ?? 0
            )
        }
    }

    func insert(_ entry: DictionaryEntry) throws {
        let aliases = try encodeAliases(entry.aliases)
        try database.execute(
            """
            INSERT INTO dictionary_entries (spoken, written, aliases, scope, priority, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [entry.spoken, entry.written, aliases, entry.scope, String(entry.priority), Date.isoNow, Date.isoNow]
        )
    }

    func update(_ entry: DictionaryEntry) throws {
        guard let id = entry.id else { return }
        let aliases = try encodeAliases(entry.aliases)
        try database.execute(
            """
            UPDATE dictionary_entries
            SET spoken = ?, written = ?, aliases = ?, scope = ?, priority = ?, updated_at = ?
            WHERE id = ?
            """,
            bindings: [entry.spoken, entry.written, aliases, entry.scope, String(entry.priority), Date.isoNow, String(id)]
        )
    }

    func delete(id: Int) throws {
        try database.execute("DELETE FROM dictionary_entries WHERE id = ?", bindings: [String(id)])
    }

    func upsertLearnedEntry(spoken rawSpoken: String, written rawWritten: String) throws {
        let spoken = rawSpoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = rawWritten.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !written.isEmpty, spoken.caseInsensitiveCompare(written) != .orderedSame else {
            return
        }

        var entries = try fetchAll()
        if let index = entries.firstIndex(where: { entry in
            entry.spoken.caseInsensitiveCompare(spoken) == .orderedSame ||
                entry.aliases.contains(where: { $0.caseInsensitiveCompare(spoken) == .orderedSame })
        }) {
            entries[index].written = written
            entries[index].priority = max(entries[index].priority, 20)
            entries[index].scope = Self.markLearned(scope: entries[index].scope)
            try update(entries[index])
            return
        }

        if let index = entries.firstIndex(where: { $0.written.caseInsensitiveCompare(written) == .orderedSame }) {
            let alreadyKnown = entries[index].spoken.caseInsensitiveCompare(spoken) == .orderedSame ||
                entries[index].aliases.contains(where: { $0.caseInsensitiveCompare(spoken) == .orderedSame })
            if !alreadyKnown {
                entries[index].aliases.append(spoken)
            }
            entries[index].priority = max(entries[index].priority, 20)
            entries[index].scope = Self.markLearned(scope: entries[index].scope)
            try update(entries[index])
            return
        }

        try insert(DictionaryEntry(id: nil, spoken: spoken, written: written, aliases: [], scope: "global,learned", priority: 20))
    }

    private static func markLearned(scope: String) -> String {
        let trimmed = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "learned" }
        let tokens = trimmed.split { $0 == "," || $0 == " " || $0 == ";" }
        guard !tokens.contains(where: { $0.caseInsensitiveCompare("learned") == .orderedSame }) else {
            return trimmed
        }
        return "\(trimmed),learned"
    }

    private func isMissingDefault(_ entry: DictionaryEntry) throws -> Bool {
        let rows = try database.query(
            "SELECT id FROM dictionary_entries WHERE spoken = ? OR written = ? LIMIT 1",
            bindings: [entry.spoken, entry.written]
        )
        return rows.isEmpty
    }

    private func encodeAliases(_ aliases: [String]) throws -> String {
        let data = try encoder.encode(aliases)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decodeAliases(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let aliases = try? JSONDecoder().decode([String].self, from: data) else {
            return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return aliases
    }

    static let defaultEntries: [DictionaryEntry] = [
        DictionaryEntry(id: nil, spoken: "typeless", written: "Typeless", aliases: ["type less"], scope: "global", priority: 10),
        DictionaryEntry(id: nil, spoken: "豆包", written: "豆包", aliases: ["doubao"], scope: "global", priority: 10),
        DictionaryEntry(id: nil, spoken: "火山方舟", written: "火山方舟", aliases: ["方舟"], scope: "global", priority: 10),
        DictionaryEntry(id: nil, spoken: "cursor", written: "Cursor", aliases: [], scope: "global", priority: 8),
        DictionaryEntry(id: nil, spoken: "swift ui", written: "SwiftUI", aliases: ["swiftui"], scope: "global", priority: 8),
        DictionaryEntry(id: nil, spoken: "whisper", written: "Whisper", aliases: ["whisper.cpp"], scope: "global", priority: 8),
        DictionaryEntry(id: nil, spoken: "tailwind", written: "Tailwind CSS", aliases: [], scope: "global", priority: 8),
        DictionaryEntry(id: nil, spoken: "插入", written: "插入", aliases: ["差路", "叉入", "插路"], scope: "global", priority: 7)
    ]
}
