import Foundation

struct HistoryItem: Identifiable, Equatable {
    let id: Int
    let rawASRText: String
    let finalText: String
    let action: String
    let activeApp: String
    let bundleIdentifier: String
    let windowTitle: String
    let model: String
    let asrProvider: String
    let llmProvider: String
    let latencyMs: Int
    let createdAt: String
}

final class HistoryStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(
        rawASRText: String,
        finalText: String,
        action: String,
        context: ActiveAppContext,
        model: String,
        asrProvider: String,
        llmProvider: String,
        latencyMs: Int
    ) throws {
        try database.execute(
            """
            INSERT INTO history
            (raw_asr_text, final_text, action, active_app, bundle_identifier, window_title, model, asr_provider, llm_provider, latency_ms, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                rawASRText,
                finalText,
                action,
                context.activeApp,
                context.bundleIdentifier,
                context.windowTitle,
                model,
                asrProvider,
                llmProvider,
                String(latencyMs),
                Date.isoNow
            ]
        )
    }

    func recent(limit: Int) throws -> [HistoryItem] {
        let rows = try database.query(
            "SELECT * FROM history ORDER BY id DESC LIMIT ?",
            bindings: [String(limit)]
        )
        return rows.compactMap(Self.item(from:))
    }

    func search(_ keyword: String) throws -> [HistoryItem] {
        let pattern = "%\(keyword)%"
        let rows = try database.query(
            """
            SELECT * FROM history
            WHERE raw_asr_text LIKE ? OR final_text LIKE ? OR active_app LIKE ?
            ORDER BY id DESC LIMIT 200
            """,
            bindings: [pattern, pattern, pattern]
        )
        return rows.compactMap(Self.item(from:))
    }

    func delete(id: Int) throws {
        try database.execute("DELETE FROM history WHERE id = ?", bindings: [String(id)])
    }

    func clear() throws {
        try database.execute("DELETE FROM history")
    }

    private static func item(from row: [String: String]) -> HistoryItem? {
        guard let id = Int(row["id"] ?? "") else { return nil }
        return HistoryItem(
            id: id,
            rawASRText: row["raw_asr_text"] ?? "",
            finalText: row["final_text"] ?? "",
            action: row["action"] ?? "",
            activeApp: row["active_app"] ?? "",
            bundleIdentifier: row["bundle_identifier"] ?? "",
            windowTitle: row["window_title"] ?? "",
            model: row["model"] ?? "",
            asrProvider: row["asr_provider"] ?? "",
            llmProvider: row["llm_provider"] ?? "",
            latencyMs: Int(row["latency_ms"] ?? "") ?? 0,
            createdAt: row["created_at"] ?? ""
        )
    }
}

extension Date {
    static var isoNow: String {
        ISO8601DateFormatter().string(from: Date())
    }
}

