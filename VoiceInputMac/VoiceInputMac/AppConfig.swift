import Foundation

struct AppConfig: Codable, Equatable {
    var asrProvider: String = "local_whisper"
    var whisperRuntime: String = "whisper_cpp"
    var whisperModel: String = "large-v3-turbo"
    var whisperModelPath: String = ""
    var whisperLanguage: String = "zh"
    var whisperKeepModelLoaded: Bool = true
    var whisperUseMetal: Bool = true
    var whisperUseCoreML: Bool = false
    var whisperEnableVAD: Bool = true
    var whisperMaxSegmentSeconds: Int = 30
    var whisperThreads: String = "auto"
    var whisperCLICommand: String = "whisper-cli"

    var llmProvider: String = "volcengine_ark"
    var arkBaseURL: String = "https://ark.cn-beijing.volces.com/api/v3"
    var arkModel: String = ""
    var arkTemperature: Double = 0.2
    var arkTimeoutSeconds: Int = 20

    var dictationHotkey: String = "Option+Space"
    var editSelectionHotkey: String = "Option+Shift+Space"
    var hotkeyMode: HotkeyMode = .pressToTalk

    var saveHistory: Bool = true
    var saveAudio: Bool = false
    var restoreClipboardAfterPaste: Bool = true
    var defaultStyleProfile: String = "auto"
    var logLevel: String = "info"
}

enum HotkeyMode: String, Codable, CaseIterable, Identifiable {
    case pressToTalk
    case toggle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pressToTalk:
            return "Press-to-talk"
        case .toggle:
            return "Toggle"
        }
    }
}

enum PipelineMode: String, Codable {
    case dictation
    case editSelection
}

enum AppPhase: String {
    case idle
    case recording
    case transcribing
    case polishing
    case injecting
    case done
    case error

    var menuTitle: String {
        switch self {
        case .idle:
            return "Idle"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .polishing:
            return "Polishing"
        case .injecting:
            return "Injecting"
        case .done:
            return "Done"
        case .error:
            return "Error"
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "record.circle.fill"
        case .transcribing:
            return "waveform"
        case .polishing:
            return "sparkles"
        case .injecting:
            return "text.cursor"
        case .done:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

enum AppError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case inputMonitoringPermissionDenied
    case asrModelMissing
    case asrFailed(String)
    case asrTimeout
    case llmAPIKeyMissing
    case llmFailed(String)
    case llmTimeout
    case jsonParseFailed(String)
    case injectionFailed(String)
    case selectedTextUnavailable
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "需要麦克风权限才能录音。请在系统设置中允许本 App 使用麦克风。"
        case .accessibilityPermissionDenied:
            return "需要辅助功能权限才能把文本插入当前 App。请在系统设置 -> 隐私与安全性 -> 辅助功能中允许本 App。"
        case .inputMonitoringPermissionDenied:
            return "需要输入监听权限才能使用全局按住说话快捷键。请在系统设置中允许本 App 监听键盘输入。"
        case .asrModelMissing:
            return "未找到 Whisper 模型文件。请在设置中选择模型路径。"
        case .asrFailed(let message):
            return "本地识别失败：\(message)"
        case .asrTimeout:
            return "本地识别超时。"
        case .llmAPIKeyMissing:
            return "未配置豆包 / 火山方舟 API Key。当前将直接插入本地识别结果。"
        case .llmFailed(let message):
            return "豆包 / 火山方舟调用失败：\(message)"
        case .llmTimeout:
            return "豆包 / 火山方舟调用超时。"
        case .jsonParseFailed(let message):
            return "模型返回内容无法解析：\(message)"
        case .injectionFailed:
            return "无法自动插入文本。已在浮窗中显示结果，可手动复制。"
        case .selectedTextUnavailable:
            return "无法读取选中文本。请确认当前 App 允许辅助功能访问，或手动复制后重试。"
        case .emptyTranscript:
            return "没有识别到可输入的语音内容。"
        }
    }
}

