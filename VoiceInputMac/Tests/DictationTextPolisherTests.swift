import XCTest
@testable import VoiceInputMac

final class DictationTextPolisherTests: XCTestCase {
    func testPolishesFeedbackAboutInsertionAndReorganization() {
        let raw = "我们来测试一下，这次看起来识别和整理应该是正常的，但插入依然不太正常。其实我觉得整理也不太正常，因为它没有把我说的话重新整理。"
        let polished = DictationTextPolisher().polish(raw)

        XCTAssertTrue(polished.contains("识别看起来是正常的"))
        XCTAssertTrue(polished.contains("整理效果也还不够好"))
        XCTAssertTrue(polished.contains("重新组织成更自然的文本"))
        XCTAssertFalse(polished.contains("其实我觉得整理"))
    }
}
