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
    var customLLMBaseURL: String = "http://127.0.0.1:8000/v1"
    var customLLMPath: String = "chat/completions"
    var customLLMModel: String = ""
    var customLLMAuthHeader: String = "Authorization"
    var customLLMAuthScheme: String = "Bearer"
    var customLLMRequiresAPIKey: Bool = false
    var customLLMExtraHeadersJSON: String = ""

    var dictationHotkey: String = "Fn+A"
    var editSelectionHotkey: String = "Fn+Shift+A"
    var hotkeyMode: HotkeyMode = .pressToTalk

    var saveHistory: Bool = true
    var saveAudio: Bool = false
    var restoreClipboardAfterPaste: Bool = true
    var defaultStyleProfile: String = "auto"
    var logLevel: String = "info"

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppConfig()

        asrProvider = try values.decodeIfPresent(String.self, forKey: .asrProvider) ?? defaults.asrProvider
        whisperRuntime = try values.decodeIfPresent(String.self, forKey: .whisperRuntime) ?? defaults.whisperRuntime
        whisperModel = try values.decodeIfPresent(String.self, forKey: .whisperModel) ?? defaults.whisperModel
        whisperModelPath = try values.decodeIfPresent(String.self, forKey: .whisperModelPath) ?? defaults.whisperModelPath
        whisperLanguage = try values.decodeIfPresent(String.self, forKey: .whisperLanguage) ?? defaults.whisperLanguage
        whisperKeepModelLoaded = try values.decodeIfPresent(Bool.self, forKey: .whisperKeepModelLoaded) ?? defaults.whisperKeepModelLoaded
        whisperUseMetal = try values.decodeIfPresent(Bool.self, forKey: .whisperUseMetal) ?? defaults.whisperUseMetal
        whisperUseCoreML = try values.decodeIfPresent(Bool.self, forKey: .whisperUseCoreML) ?? defaults.whisperUseCoreML
        whisperEnableVAD = try values.decodeIfPresent(Bool.self, forKey: .whisperEnableVAD) ?? defaults.whisperEnableVAD
        whisperMaxSegmentSeconds = try values.decodeIfPresent(Int.self, forKey: .whisperMaxSegmentSeconds) ?? defaults.whisperMaxSegmentSeconds
        whisperThreads = try values.decodeIfPresent(String.self, forKey: .whisperThreads) ?? defaults.whisperThreads
        whisperCLICommand = try values.decodeIfPresent(String.self, forKey: .whisperCLICommand) ?? defaults.whisperCLICommand

        llmProvider = try values.decodeIfPresent(String.self, forKey: .llmProvider) ?? defaults.llmProvider
        arkBaseURL = try values.decodeIfPresent(String.self, forKey: .arkBaseURL) ?? defaults.arkBaseURL
        arkModel = try values.decodeIfPresent(String.self, forKey: .arkModel) ?? defaults.arkModel
        arkTemperature = try values.decodeIfPresent(Double.self, forKey: .arkTemperature) ?? defaults.arkTemperature
        arkTimeoutSeconds = try values.decodeIfPresent(Int.self, forKey: .arkTimeoutSeconds) ?? defaults.arkTimeoutSeconds
        customLLMBaseURL = try values.decodeIfPresent(String.self, forKey: .customLLMBaseURL) ?? defaults.customLLMBaseURL
        customLLMPath = try values.decodeIfPresent(String.self, forKey: .customLLMPath) ?? defaults.customLLMPath
        customLLMModel = try values.decodeIfPresent(String.self, forKey: .customLLMModel) ?? defaults.customLLMModel
        customLLMAuthHeader = try values.decodeIfPresent(String.self, forKey: .customLLMAuthHeader) ?? defaults.customLLMAuthHeader
        customLLMAuthScheme = try values.decodeIfPresent(String.self, forKey: .customLLMAuthScheme) ?? defaults.customLLMAuthScheme
        customLLMRequiresAPIKey = try values.decodeIfPresent(Bool.self, forKey: .customLLMRequiresAPIKey) ?? defaults.customLLMRequiresAPIKey
        customLLMExtraHeadersJSON = try values.decodeIfPresent(String.self, forKey: .customLLMExtraHeadersJSON) ?? defaults.customLLMExtraHeadersJSON

        dictationHotkey = try values.decodeIfPresent(String.self, forKey: .dictationHotkey) ?? defaults.dictationHotkey
        editSelectionHotkey = try values.decodeIfPresent(String.self, forKey: .editSelectionHotkey) ?? defaults.editSelectionHotkey
        hotkeyMode = try values.decodeIfPresent(HotkeyMode.self, forKey: .hotkeyMode) ?? defaults.hotkeyMode

        saveHistory = try values.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? defaults.saveHistory
        saveAudio = try values.decodeIfPresent(Bool.self, forKey: .saveAudio) ?? defaults.saveAudio
        restoreClipboardAfterPaste = try values.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ?? defaults.restoreClipboardAfterPaste
        defaultStyleProfile = try values.decodeIfPresent(String.self, forKey: .defaultStyleProfile) ?? defaults.defaultStyleProfile
        logLevel = try values.decodeIfPresent(String.self, forKey: .logLevel) ?? defaults.logLevel
    }
}

extension AppConfig {
    mutating func migrateLegacyHotkeyDefaults() {
        guard dictationHotkey == "Option+Space",
              editSelectionHotkey == "Option+Shift+Space" else {
            return
        }
        dictationHotkey = "Fn+A"
        editSelectionHotkey = "Fn+Shift+A"
    }
}

enum LLMProviderID: String, Codable, CaseIterable, Identifiable {
    case volcengineArk = "volcengine_ark"
    case customOpenAICompatible = "custom_openai_compatible"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volcengineArk:
            return "豆包 / 火山方舟"
        case .customOpenAICompatible:
            return "自定义 OpenAI-compatible"
        }
    }
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
            return "未配置当前文本模型 API Key。当前将直接插入本地识别结果。"
        case .llmFailed(let message):
            return "文本模型调用失败：\(message)"
        case .llmTimeout:
            return "文本模型调用超时。"
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
