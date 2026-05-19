import Foundation

struct DictionaryEntry: Codable, Identifiable, Equatable {
    var id: Int?
    var spoken: String
    var written: String
    var aliases: [String]
    var scope: String
    var priority: Int

    var aliasesText: String {
        aliases.joined(separator: ", ")
    }

    var promptLine: String {
        let aliasText = aliases.isEmpty ? "" : " aliases=\(aliases.joined(separator: "/"))"
        return "- \(spoken) -> \(written)\(aliasText)"
    }
}

