import Foundation

struct StyleProfile: Codable, Identifiable, Equatable {
    var id: Int?
    var name: String
    var app_pattern: String
    var prompt_suffix: String
    var examples: String

    var stableID: String { "\(id ?? 0)-\(name)" }
}

final class StyleProfileStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func seedDefaultsIfNeeded() throws {
        let count = try database.query("SELECT COUNT(*) AS count FROM style_profiles").first?["count"] ?? "0"
        guard count == "0" else { return }
        for profile in Self.defaultProfiles {
            try insert(profile)
        }
    }

    func fetchAll() throws -> [StyleProfile] {
        let rows = try database.query("SELECT * FROM style_profiles ORDER BY id ASC")
        return rows.map {
            StyleProfile(
                id: Int($0["id"] ?? ""),
                name: $0["name"] ?? "",
                app_pattern: $0["app_pattern"] ?? "",
                prompt_suffix: $0["prompt_suffix"] ?? "",
                examples: $0["examples"] ?? ""
            )
        }
    }

    func insert(_ profile: StyleProfile) throws {
        try database.execute(
            """
            INSERT INTO style_profiles (name, app_pattern, prompt_suffix, examples, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [profile.name, profile.app_pattern, profile.prompt_suffix, profile.examples, Date.isoNow, Date.isoNow]
        )
    }

    func update(_ profile: StyleProfile) throws {
        guard let id = profile.id else { return }
        try database.execute(
            """
            UPDATE style_profiles
            SET name = ?, app_pattern = ?, prompt_suffix = ?, examples = ?, updated_at = ?
            WHERE id = ?
            """,
            bindings: [profile.name, profile.app_pattern, profile.prompt_suffix, profile.examples, Date.isoNow, String(id)]
        )
    }

    func delete(id: Int) throws {
        try database.execute("DELETE FROM style_profiles WHERE id = ?", bindings: [String(id)])
    }

    func matchProfile(
        appName: String,
        bundleIdentifier: String,
        profiles: [StyleProfile],
        defaultProfileName: String
    ) -> StyleProfile? {
        let haystack = "\(appName) \(bundleIdentifier)"
        if defaultProfileName != "auto",
           let forced = profiles.first(where: { $0.name == defaultProfileName }) {
            return forced
        }
        for profile in profiles {
            if let regex = try? NSRegularExpression(pattern: profile.app_pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: haystack, range: NSRange(haystack.startIndex..., in: haystack)) != nil {
                return profile
            }
        }
        return nil
    }

    static let defaultProfiles: [StyleProfile] = [
        StyleProfile(id: nil, name: "chat", app_pattern: "WeChat|Telegram|Feishu|Slack|Discord", prompt_suffix: "输出应简短、自然、像日常聊天。不要过度正式。不要自动添加称呼或签名。", examples: ""),
        StyleProfile(id: nil, name: "email", app_pattern: "Mail|Gmail|Outlook", prompt_suffix: "输出应完整、礼貌、适合邮件沟通。可以适度正式，但不要编造称呼、签名或承诺。", examples: ""),
        StyleProfile(id: nil, name: "notes", app_pattern: "Notion|Obsidian|Notes", prompt_suffix: "输出可以使用 Markdown、标题、列表和清晰段落。", examples: ""),
        StyleProfile(id: nil, name: "code", app_pattern: "Cursor|Code|Xcode|Terminal|iTerm", prompt_suffix: "保留代码符号、变量名、技术名词和英文缩写。不要把代码片段自然语言化。", examples: "")
    ]
}
