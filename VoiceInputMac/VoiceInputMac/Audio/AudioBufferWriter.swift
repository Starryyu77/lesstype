import Foundation

enum AudioBufferWriter {
    static func makeTemporaryWAVURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceinput-\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }

    static func writeMono16WAV(samples: [Float], inputSampleRate: Double, to url: URL, targetSampleRate: Int = 16_000) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let outputSamples = resample(samples: samples, inputSampleRate: inputSampleRate, targetSampleRate: Double(targetSampleRate))

        var data = Data()
        let bytesPerSample = 2
        let subchunk2Size = UInt32(outputSamples.count * bytesPerSample)
        let chunkSize = UInt32(36) + subchunk2Size
        let byteRate = UInt32(targetSampleRate * bytesPerSample)
        let blockAlign = UInt16(bytesPerSample)

        data.appendASCII("RIFF")
        data.appendLittleEndian(chunkSize)
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(targetSampleRate))
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(subchunk2Size)

        for sample in outputSamples {
            let clamped = min(max(sample, -1), 1)
            let scaled = Int((clamped * Float(Int16.max)).rounded())
            data.appendLittleEndian(Int16(clamping: scaled))
        }

        try data.write(to: url, options: .atomic)
    }

    private static func resample(samples: [Float], inputSampleRate: Double, targetSampleRate: Double) -> [Float] {
        guard !samples.isEmpty, inputSampleRate > 0, targetSampleRate > 0 else {
            return []
        }
        if abs(inputSampleRate - targetSampleRate) < 0.1 {
            return samples
        }

        let outputCount = max(1, Int((Double(samples.count) / inputSampleRate * targetSampleRate).rounded()))
        var output = [Float]()
        output.reserveCapacity(outputCount)

        for outputIndex in 0..<outputCount {
            let inputPosition = Double(outputIndex) * inputSampleRate / targetSampleRate
            let lowerIndex = min(Int(inputPosition), samples.count - 1)
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let fraction = Float(inputPosition - Double(lowerIndex))
            let interpolated = samples[lowerIndex] + (samples[upperIndex] - samples[lowerIndex]) * fraction
            output.append(interpolated)
        }
        return output
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
