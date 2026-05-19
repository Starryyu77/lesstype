import XCTest
@testable import VoiceInputMac

final class DictationTextPolisherTests: XCTestCase {
    func testPolishesFeedbackAboutInsertionAndReorganization() {
        let raw = "我们来测试一下，这次看起来识别和整理应该是正常的，但插入依然不太正常。其实我觉得整理也不太正常，因为它没有把我说的话重新整理。"
        let polished = DictationTextPolisher().polish(raw)

        XCTAssertTrue(polished.contains("识别应该是正常的"))
        XCTAssertTrue(polished.contains("插入依然不太正常"))
        XCTAssertTrue(polished.contains("整理也不太正常"))
        XCTAssertTrue(polished.contains("没有把我说的话重新整理"))
        XCTAssertFalse(polished.contains("其实我觉得整理"))
        XCTAssertFalse(polished.contains("整理应该是正常"))
        XCTAssertFalse(polished.contains("更自然的文本"))
    }

    func testRemovesSupersededPositiveJudgementWhenLaterCorrectionDisagrees() {
        let raw = "我们来测试一下。这次识别和整理应该是正常的，但插入依然不太正常。另外，整理也不太正常，它没有把我说的话重新整理。"
        let polished = DictationTextPolisher().polish(raw)

        XCTAssertTrue(polished.contains("识别应该是正常的"))
        XCTAssertTrue(polished.contains("插入依然不太正常"))
        XCTAssertTrue(polished.contains("整理也不太正常"))
        XCTAssertFalse(polished.contains("整理应该是正常"))
        XCTAssertFalse(polished.contains("整理看起来是正常"))
    }

    func testRemovesWhisperTailCorrectionArtifact() {
        let raw = "它的时间精度还是有点问题，而且它会在一句话讲完之后，有一个要求后续变更正的这个词会出现。这不奇怪吗？"
        let polished = DictationTextPolisher().polish(raw)

        XCTAssertTrue(polished.contains("时间精度还是有点问题"))
        XCTAssertTrue(polished.contains("这不奇怪吗"))
        XCTAssertFalse(polished.contains("要求后续"))
        XCTAssertFalse(polished.contains("变更正"))
    }

    func testRemovesCorrectionArtifactWithFillerWordsAndPrefix() {
        let raw = "要求后续变更，还是会有这个不该出现的内容在"
        let polished = DictationTextPolisher().polish(raw)

        XCTAssertEqual(polished, "还是会有这个不该出现的内容在")
        XCTAssertFalse(polished.contains("要求后续"))
    }

    func testRemovesCorrectionArtifactWithWhatFiller() {
        let raw = "它会有一个什么要求后续变更正的这个词出现"
        let polished = DictationTextPolisher().polish(raw)

        XCTAssertEqual(polished, "它会出现")
        XCTAssertFalse(polished.contains("要求后续"))
        XCTAssertFalse(polished.contains("什么"))
    }

    func testRemovesArtifactFromExistingFocusedTextValue() {
        let raw = "123123 我们测试一下 要求后续变更"
        let cleaned = DictationTextPolisher().removeKnownASRArtifacts(in: raw)

        XCTAssertEqual(cleaned, "123123 我们测试一下")
    }
}
