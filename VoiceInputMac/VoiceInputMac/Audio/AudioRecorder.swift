import AVFoundation
import Foundation

final class AudioRecorder: ObservableObject {
    @Published private(set) var meterLevel: Float = 0

    private let engine = AVAudioEngine()
    private var outputFile: AVAudioFile?
    private var outputURL: URL?
    private var converter: AVAudioConverter?
    private var isRecording = false
    private var stopWorkItem: DispatchWorkItem?
    private var enableVAD = false
    private var vadDetector = VADDetector()
    private var didHearSpeech = false
    private var silenceStartedAt: Date?
    private var didRequestAutoStop = false
    private var recordingStartedAt: Date?
    private var onAutoStop: (() -> Void)?

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
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true) else {
            throw AppError.asrFailed("Unable to create 16kHz mono PCM format")
        }
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        let url = AudioBufferWriter.makeTemporaryWAVURL()
        outputURL = url
        outputFile = try AVAudioFile(forWriting: url, settings: targetFormat.settings)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.write(buffer: buffer, inputFormat: inputFormat, targetFormat: targetFormat)
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
        outputFile = nil
        converter = nil
        onAutoStop = nil
        guard let url = outputURL else {
            throw AppError.asrFailed("Recording output was not created")
        }
        return url
    }

    private func write(buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, targetFormat: AVAudioFormat) {
        updateMeter(buffer: buffer)
        guard let converter, let outputFile else { return }

        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return }

        var didProvideBuffer = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if didProvideBuffer {
                status.pointee = .noDataNow
                return nil
            }
            didProvideBuffer = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, converted.frameLength > 0 {
            try? outputFile.write(from: converted)
        }
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

    private func updateMeter(buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        var sum: Float = 0
        for index in 0..<count {
            sum += channel[index] * channel[index]
        }
        let rms = sqrt(sum / Float(count))
        Task { @MainActor in
            self.meterLevel = min(max(rms * 20, 0), 1)
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
