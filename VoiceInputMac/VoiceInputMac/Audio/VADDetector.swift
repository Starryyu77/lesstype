import AVFoundation
import Foundation

struct VADDetector {
    var silenceThreshold: Float = 0.012
    var requiredSilenceSeconds: Double = 1.2

    func isSilent(buffer: AVAudioPCMBuffer) -> Bool {
        guard let channel = buffer.floatChannelData?[0] else { return true }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return true }
        var sum: Float = 0
        for index in 0..<count {
            sum += channel[index] * channel[index]
        }
        return sqrt(sum / Float(count)) < silenceThreshold
    }
}

