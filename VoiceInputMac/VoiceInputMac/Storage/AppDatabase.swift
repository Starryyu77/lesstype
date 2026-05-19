import Foundation
import SQLite3

final class AppDatabase {
    let url: URL
    private var db: OpaquePointer?

    private init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw AppError.asrFailed("Unable to open SQLite database")
        }
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    static func openDefault() throws -> AppDatabase {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("VoiceInputMac", isDirectory: true)
        return try AppDatabase(url: dir.appendingPathComponent("VoiceInputMac.sqlite3"))
    }

    func execute(_ sql: String, bindings: [String?] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError()
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError()
        }
    }

    func query(_ sql: String, bindings: [String?] = []) throws -> [[String: String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError()
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        var rows: [[String: String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, index))
                if let cString = sqlite3_column_text(statement, index) {
                    row[name] = String(cString: cString)
                } else {
                    row[name] = ""
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func bind(_ bindings: [String?], to statement: OpaquePointer?) throws {
        for (index, value) in bindings.enumerated() {
            let sqliteIndex = Int32(index + 1)
            if let value {
                sqlite3_bind_text(statement, sqliteIndex, value, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, sqliteIndex)
            }
        }
    }

    private func sqliteError() -> Error {
        let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown SQLite error"
        return AppError.asrFailed(message)
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS dictionary_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          spoken TEXT NOT NULL,
          written TEXT NOT NULL,
          aliases TEXT,
          scope TEXT DEFAULT 'global',
          priority INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS style_profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          app_pattern TEXT,
          prompt_suffix TEXT,
          examples TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          raw_asr_text TEXT NOT NULL,
          final_text TEXT NOT NULL,
          action TEXT NOT NULL,
          active_app TEXT,
          bundle_identifier TEXT,
          window_title TEXT,
          model TEXT,
          asr_provider TEXT,
          llm_provider TEXT,
          latency_ms INTEGER,
          created_at TEXT NOT NULL
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        """)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

