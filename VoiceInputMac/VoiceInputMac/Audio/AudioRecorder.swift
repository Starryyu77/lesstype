import AVFoundation
import Foundation

final class AudioRecorder: ObservableObject {
    @Published private(set) var meterLevel: Float = 0

    private let engine = AVAudioEngine()
    private var outputURL: URL?
    private var isRecording = false
    private var stopWorkItem: DispatchWorkItem?
    private var enableVAD = false
    private var vadDetector = VADDetector()
    private var didHearSpeech = false
    private var silenceStartedAt: Date?
    private var didRequestAutoStop = false
    private var recordingStartedAt: Date?
    private var onAutoStop: (() -> Void)?
    private var inputSampleRate: Double = 0
    private var capturedSamples: [Float] = []
    private let captureLock = NSLock()
    private let meterLock = NSLock()
    private var meterUpdatePending = false

    func startRecording(maxDurationSeconds: Int, enableVAD: Bool = false, onAutoStop: (() -> Void)? = nil) async throws {
        guard !isRecording else { return }
        let granted = await requestMicrophonePermission()
        guard granted else {
            throw AppError.microphonePermissionDenied
        }

        self.enableVAD = enableVAD
        self.onAutoStop = onAutoStop
        didHearSpeech = false
        silenceStartedAt = nil
        didRequestAutoStop = false
        recordingStartedAt = Date()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        resetCapture(inputFormat: inputFormat, maxDurationSeconds: maxDurationSeconds)

        let url = AudioBufferWriter.makeTemporaryWAVURL()
        outputURL = url

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.capture(buffer: buffer)
            self?.checkVAD(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true

        let item = DispatchWorkItem { [weak self] in
            _ = try? self?.stopRecording()
        }
        stopWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(maxDurationSeconds), execute: item)
    }

    func stopRecording() throws -> URL {
        guard isRecording else {
            if let outputURL { return outputURL }
            throw AppError.asrFailed("Recording was not started")
        }
        stopWorkItem?.cancel()
        stopWorkItem = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        onAutoStop = nil
        guard let url = outputURL else {
            throw AppError.asrFailed("Recording output was not created")
        }
        let samples = drainCapturedSamples()
        try AudioBufferWriter.writeMono16WAV(samples: samples, inputSampleRate: inputSampleRate, to: url)
        return url
    }

    private func capture(buffer: AVAudioPCMBuffer) {
        let samples = monoSamples(from: buffer)
        guard !samples.isEmpty else { return }
        captureLock.lock()
        capturedSamples.append(contentsOf: samples)
        captureLock.unlock()
        updateMeter(samples: samples)
    }

    private func resetCapture(inputFormat: AVAudioFormat, maxDurationSeconds: Int) {
        inputSampleRate = inputFormat.sampleRate
        captureLock.lock()
        capturedSamples.removeAll(keepingCapacity: true)
        capturedSamples.reserveCapacity(Int(inputFormat.sampleRate * Double(maxDurationSeconds)))
        captureLock.unlock()
    }

    private func drainCapturedSamples() -> [Float] {
        captureLock.lock()
        let samples = capturedSamples
        capturedSamples.removeAll(keepingCapacity: false)
        captureLock.unlock()
        return samples
    }

    private func monoSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        let frameCount = Int(buffer.frameLength)
        let channelCount = max(Int(buffer.format.channelCount), 1)
        guard frameCount > 0 else { return [] }

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            if let channels = buffer.floatChannelData {
                var output = [Float](repeating: 0, count: frameCount)
                for channelIndex in 0..<channelCount {
                    let channel = channels[channelIndex]
                    for frameIndex in 0..<frameCount {
                        output[frameIndex] += channel[frameIndex] / Float(channelCount)
                    }
                }
                return output
            }
            return interleavedMonoSamples(buffer: buffer, frameCount: frameCount, channelCount: channelCount, as: Float.self) { $0 }

        case .pcmFormatInt16:
            if let channels = buffer.int16ChannelData {
                var output = [Float](repeating: 0, count: frameCount)
                for channelIndex in 0..<channelCount {
                    let channel = channels[channelIndex]
                    for frameIndex in 0..<frameCount {
                        output[frameIndex] += Float(channel[frameIndex]) / Float(Int16.max) / Float(channelCount)
                    }
                }
                return output
            }
            return interleavedMonoSamples(buffer: buffer, frameCount: frameCount, channelCount: channelCount, as: Int16.self) {
                Float($0) / Float(Int16.max)
            }

        default:
            return []
        }
    }

    private func interleavedMonoSamples<T>(
        buffer: AVAudioPCMBuffer,
        frameCount: Int,
        channelCount: Int,
        as type: T.Type,
        normalize: (T) -> Float
    ) -> [Float] {
        let audioBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        guard audioBuffers.count == 1, let data = audioBuffers[0].mData else { return [] }
        let values = data.assumingMemoryBound(to: T.self)
        var output = [Float](repeating: 0, count: frameCount)
        for frameIndex in 0..<frameCount {
            var sum: Float = 0
            for channelIndex in 0..<channelCount {
                sum += normalize(values[frameIndex * channelCount + channelIndex])
            }
            output[frameIndex] = sum / Float(channelCount)
        }
        return output
    }

    private func checkVAD(buffer: AVAudioPCMBuffer) {
        guard enableVAD, !didRequestAutoStop else { return }
        let elapsed = Date().timeIntervalSince(recordingStartedAt ?? Date())
        guard elapsed > 0.8 else { return }

        let silent = vadDetector.isSilent(buffer: buffer)
        if !silent {
            didHearSpeech = true
            silenceStartedAt = nil
            return
        }

        guard didHearSpeech else { return }
        if silenceStartedAt == nil {
            silenceStartedAt = Date()
        }
        if let silenceStartedAt,
           Date().timeIntervalSince(silenceStartedAt) >= vadDetector.requiredSilenceSeconds {
            didRequestAutoStop = true
            DispatchQueue.main.async { [weak self] in
                self?.onAutoStop?()
            }
        }
    }

    private func updateMeter(samples: [Float]) {
        guard !samples.isEmpty else { return }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(samples.count))
        let level = min(max(rms * 20, 0), 1)

        meterLock.lock()
        guard !meterUpdatePending else {
            meterLock.unlock()
            return
        }
        meterUpdatePending = true
        meterLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.meterLevel = level
            self.meterLock.lock()
            self.meterUpdatePending = false
            self.meterLock.unlock()
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
