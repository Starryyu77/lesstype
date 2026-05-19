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
}
