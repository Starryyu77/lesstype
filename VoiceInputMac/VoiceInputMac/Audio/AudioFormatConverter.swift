import AVFoundation
import Foundation

struct AudioFormatConverter {
    static func targetWhisperFormat() -> AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
    }
}

