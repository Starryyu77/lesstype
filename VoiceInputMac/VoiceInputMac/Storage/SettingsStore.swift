import Foundation

final class SettingsStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func loadConfig() -> AppConfig {
        guard let value = try? database.query("SELECT value FROM app_settings WHERE key = ?", bindings: ["app_config"]).first?["value"],
              let data = value.data(using: .utf8),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    func saveConfig(_ config: AppConfig) throws {
        let data = try JSONEncoder().encode(config)
        let value = String(data: data, encoding: .utf8) ?? "{}"
        try database.execute(
            """
            INSERT INTO app_settings (key, value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
            """,
            bindings: ["app_config", value, Date.isoNow]
        )
    }
}
