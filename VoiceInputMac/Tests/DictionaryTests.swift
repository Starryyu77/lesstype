import XCTest
@testable import VoiceInputMac

final class DictionaryTests: XCTestCase {
    func testDictionaryNormalizerRewritesCommonTerms() {
        let raw = "帮我写一下这个 cursor 里面 swift ui 和 whisper 点 cpp 的集成方案"
        let normalized = DictionaryNormalizer().normalize(raw, entries: DictionaryStore.defaultEntries)
        XCTAssertTrue(normalized.contains("Cursor"))
        XCTAssertTrue(normalized.contains("SwiftUI"))
        XCTAssertTrue(normalized.contains("whisper.cpp"))
    }

    func testDictionaryNormalizerRewritesTechnicalPronunciationVariants() {
        let raw = "帮我写一下 swift you eye 和 维斯破 cpp 在 cursor 里面的集成方案"
        let normalized = DictionaryNormalizer().normalize(raw, entries: DictionaryStore.defaultEntries)

        XCTAssertTrue(normalized.contains("SwiftUI"))
        XCTAssertTrue(normalized.contains("whisper.cpp"))
        XCTAssertTrue(normalized.contains("Cursor"))
        XCTAssertFalse(normalized.localizedCaseInsensitiveContains("swift you eye"))
        XCTAssertFalse(normalized.contains("维斯破"))
    }

    func testDictionaryNormalizerDoesNotDuplicateWrittenSuffixes() {
        let raw = "在这个项目里面，Cursor 和 Tailwind CSS 的配置先不要动"
        let normalized = DictionaryNormalizer().normalize(raw, entries: DictionaryStore.defaultEntries)

        XCTAssertTrue(normalized.contains("Tailwind CSS"))
        XCTAssertFalse(normalized.contains("Tailwind CSS CSS"))
    }

    func testDictionaryNormalizerFixesDictationHomophonesAndSpokenPhrases() {
        let raw = "这个差路依然不太正常还有一个问题就是他好像没有办法去对我们说的话进行一个整理"
        let normalized = DictionaryNormalizer().normalize(raw, entries: DictionaryStore.defaultEntries)
        XCTAssertTrue(normalized.contains("插入"))
        XCTAssertFalse(normalized.contains("差路"))
        XCTAssertFalse(normalized.contains("进行一个整理"))
        XCTAssertTrue(normalized.contains("无法"))
    }

    func testLearnedEntryAddsAliasToExistingWrittenForm() throws {
        let store = try makeTemporaryDictionaryStore()

        try store.insert(DictionaryEntry(id: nil, spoken: "swift ui", written: "SwiftUI", aliases: [], scope: "global", priority: 8))
        try store.upsertLearnedEntry(spoken: "Swift You Eye", written: "SwiftUI")

        let entries = try store.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.written, "SwiftUI")
        XCTAssertEqual(entries.first?.priority, 20)
        XCTAssertTrue(entries.first?.aliases.contains("Swift You Eye") == true)
        XCTAssertTrue(entries.first?.isLearned == true)
    }

    func testNewLearnedEntryIsMarkedLearned() throws {
        let store = try makeTemporaryDictionaryStore()

        try store.upsertLearnedEntry(spoken: "Transformer Xr", written: "Transformer-XL")

        let entries = try store.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.spoken, "Transformer Xr")
        XCTAssertEqual(entries.first?.written, "Transformer-XL")
        XCTAssertTrue(entries.first?.isLearned == true)
    }

    private func makeTemporaryDictionaryStore() throws -> DictionaryStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceInputMac-\(UUID().uuidString)")
            .appendingPathComponent("test.sqlite3")
        let database = try AppDatabase.open(url: url)
        return DictionaryStore(database: database)
    }
}
