import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var phase: AppPhase = .idle
    @Published var message: String = "Ready"
    @Published var lastError: String?
    @Published var config: AppConfig = AppConfig()
    @Published var dictionaryEntries: [DictionaryEntry] = []
    @Published var styleProfiles: [StyleProfile] = []
    @Published var historyItems: [HistoryItem] = []
    @Published var apiKeyDraft: String = ""
    @Published var asrCheckMessage: String = ""
    @Published var llmCheckMessage: String = ""
    @Published var lastHotkeyEvent: String = "尚未捕获按键事件"
    @Published var hotkeySettingsMessage: String = ""

    let database: AppDatabase
    let historyStore: HistoryStore
    let dictionaryStore: DictionaryStore
    let styleProfileStore: StyleProfileStore
    let keychainStore: KeychainStore

    private let settingsStore: SettingsStore
    private let audioRecorder: AudioRecorder
    private let asrService: ASRProvider
    private let promptBuilder: PromptBuilder
    private let llmProvider: LLMProvider
    private let pasteboardInjector: TextInjector
    private let accessibilityInjector: AccessibilityInjector
    private let eventTyper = CGEventTyper()
    private let activeAppDetector: ActiveAppDetector
    private let selectedTextReader: SelectedTextReader
    private let normalizer = DictionaryNormalizer()
    private let textPolisher = DictationTextPolisher()
    private let commandRouter = CommandRouter()
    private let hotKeyManager = HotKeyManager()

    private var activeRecordingMode: PipelineMode?
    private var selectedTextAtRecordingStart: String = ""
    private var appContextAtRecordingStart: ActiveAppContext?
    private var recordingStartedAt: Date?
    private var isPipelineRunning = false

    private init() {
        do {
            database = try AppDatabase.openDefault()
        } catch {
            fatalError("Unable to open local database: \(error)")
        }
        settingsStore = SettingsStore(database: database)
        historyStore = HistoryStore(database: database)
        dictionaryStore = DictionaryStore(database: database)
        styleProfileStore = StyleProfileStore(database: database)
        keychainStore = KeychainStore(service: "VoiceInputMac.Ark")
        audioRecorder = AudioRecorder()
        asrService = WhisperCliService()
        promptBuilder = PromptBuilder()
        llmProvider = OpenAICompatibleClient(
            configProvider: { AppState.shared.config },
            keychainStore: keychainStore,
            apiKeyProvider: { AppState.shared.apiKeyDraft }
        )
        pasteboardInjector = PasteboardInjector(restoreClipboard: { AppState.shared.config.restoreClipboardAfterPaste })
        accessibilityInjector = AccessibilityInjector()
        activeAppDetector = ActiveAppDetector()
        selectedTextReader = SelectedTextReader()
    }

    func start() {
        loadLocalState()
        _ = AccessibilityPermission.isTrusted(prompt: true)
        startHotKeyManager()
    }

    private func startHotKeyManager() {
        hotKeyManager.start(
            dictationHotkey: config.dictationHotkey,
            editSelectionHotkey: config.editSelectionHotkey,
            hotkeyMode: config.hotkeyMode,
            onPress: { [weak self] mode in
                Task { @MainActor in self?.beginRecording(mode: mode) }
            },
            onRelease: { [weak self] mode in
                Task { @MainActor in self?.finishRecording(mode: mode) }
            },
            onEventDebug: { [weak self] description in
                Task { @MainActor in self?.lastHotkeyEvent = description }
            }
        )
    }

    func stop() {
        hotKeyManager.stop()
    }

    func loadLocalState() {
        var loadedConfig = settingsStore.loadConfig()
        loadedConfig.migrateLegacyHotkeyDefaults()
        config = loadedConfig
        try? settingsStore.saveConfig(config)
        loadSelectedAPIKeyDraft()
        do {
            try dictionaryStore.seedDefaultsIfNeeded()
            try styleProfileStore.seedDefaultsIfNeeded()
            dictionaryEntries = try dictionaryStore.fetchAll()
            styleProfiles = try styleProfileStore.fetchAll()
            historyItems = try historyStore.recent(limit: 100)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func saveConfig() {
        do {
            try settingsStore.saveConfig(config)
            hotKeyManager.update(
                dictationHotkey: config.dictationHotkey,
                editSelectionHotkey: config.editSelectionHotkey,
                hotkeyMode: config.hotkeyMode
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func saveAPIKey() {
        do {
            try keychainStore.setSecret(apiKeyDraft, account: LLMEndpoint.selected(from: config).keychainAccount)
            message = "API Key saved to Keychain"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func useFnHotkeys() {
        config.dictationHotkey = "Fn+A"
        config.editSelectionHotkey = "Fn+Shift+A"
        saveConfig()
    }

    func useReliableFallbackHotkeys() {
        config.dictationHotkey = "Control+Option+A"
        config.editSelectionHotkey = "Control+Option+Shift+A"
        saveConfig()
    }

    func useToggleRecordingMode() {
        config.hotkeyMode = .toggle
        saveConfig()
    }

    func setHotkeyCaptureActive(_ active: Bool) {
        if active {
            hotKeyManager.stop()
        } else {
            startHotKeyManager()
        }
    }

    func assignHotkey(_ definition: HotKeyDefinition, to mode: PipelineMode) {
        let value = definition.displayName
        let otherDefinition = mode == .dictation
            ? HotKeyDefinition(rawValue: config.editSelectionHotkey)
            : HotKeyDefinition(rawValue: config.dictationHotkey)
        let conflict = otherDefinition == definition
        guard !conflict else {
            hotkeySettingsMessage = "这个快捷键已经被另一个语音功能使用。"
            return
        }

        switch mode {
        case .dictation:
            config.dictationHotkey = value
        case .editSelection:
            config.editSelectionHotkey = value
        }
        saveConfig()
        hotkeySettingsMessage = "\(hotkeyTitle(for: mode)) 已设置为 \(value)"
    }

    func hotkeyTitle(for mode: PipelineMode) -> String {
        switch mode {
        case .dictation:
            return "普通听写"
        case .editSelection:
            return "编辑选中文本"
        }
    }

    func selectLLMProvider(_ provider: String) {
        config.llmProvider = provider
        saveConfig()
        loadSelectedAPIKeyDraft()
    }

    private func loadSelectedAPIKeyDraft() {
        let account = LLMEndpoint.selected(from: config).keychainAccount
        apiKeyDraft = (try? keychainStore.getSecret(account: account)) ?? ""
        if !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try? keychainStore.setSecret(apiKeyDraft, account: account)
        }
    }

    func validateASRSetup() {
        Task {
            let modelOK = WhisperModelManager().validateModelPath(config.whisperModelPath)
            guard modelOK else {
                asrCheckMessage = "模型文件不存在：\(config.whisperModelPath.isEmpty ? "未配置" : config.whisperModelPath)"
                return
            }
            let cliOK = await ProcessProbe.commandExists(config.whisperCLICommand)
            asrCheckMessage = cliOK
                ? "ASR 配置可用：已找到模型和 \(config.whisperCLICommand)"
                : "找不到 \(config.whisperCLICommand)。请安装 whisper.cpp 或填写完整 CLI 路径。"
        }
    }

    func testLLMConnection() {
        Task {
            do {
                saveAPIKey()
                let endpoint = LLMEndpoint.selected(from: config)
                let result = try await llmProvider.complete(
                    systemPrompt: "你是连接测试。只返回 JSON。",
                    userPrompt: #"请返回 {"action":"noop","text":"ok","detected_language":"zh","format":"plain","confidence":1.0,"warnings":[]}"#,
                    options: LLMOptions(
                        model: endpoint.model,
                        temperature: 0,
                        timeoutSeconds: endpoint.timeoutSeconds,
                        responseFormat: "json_object"
                    )
                )
                llmCheckMessage = result.parsed == nil
                    ? "连接成功，但返回不是预期 JSON。"
                    : "连接成功，耗时 \(result.durationMs) ms。"
            } catch {
                llmCheckMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func beginRecording(mode: PipelineMode) {
        guard !isPipelineRunning, phase == .idle || phase == .done || phase == .error else { return }
        activeRecordingMode = mode
        selectedTextAtRecordingStart = ""
        appContextAtRecordingStart = activeAppDetector.currentContext()
        recordingStartedAt = Date()

        if mode == .editSelection {
            selectedTextAtRecordingStart = (try? selectedTextReader.readSelectedText()) ?? ""
        }

        Task {
            do {
                phase = .recording
                message = recordingMessage(for: mode)
                DictationOverlayPresenter.shared.show(message: message, phase: phase)
                try await audioRecorder.startRecording(
                    maxDurationSeconds: config.hotkeyMode == .toggle ? 0 : config.whisperMaxSegmentSeconds,
                    enableVAD: false,
                    onMeterLevel: { level in
                        Task { @MainActor in
                            DictationOverlayPresenter.shared.updateLevel(level)
                        }
                    },
                    onAutoStop: { [weak self] in
                        guard let self else { return }
                        Task { @MainActor in
                            if self.phase == .recording {
                                self.finishRecording(mode: mode)
                            }
                        }
                    }
                )
            } catch {
                await handle(error)
            }
        }
    }

    private func recordingMessage(for mode: PipelineMode) -> String {
        if config.hotkeyMode == .toggle {
            return mode == .dictation ? "正在录音，再按一次以输入" : "正在录音编辑指令，再按一次以替换"
        }
        return mode == .dictation ? "正在录音，松开以输入" : "正在录音编辑指令，松开以替换"
    }

    func finishRecording(mode: PipelineMode) {
        guard !isPipelineRunning, activeRecordingMode == mode || activeRecordingMode == nil else { return }
        isPipelineRunning = true
        Task {
            do {
                let audioURL = try audioRecorder.stopRecording()
                try await runPipeline(audioURL: audioURL, mode: mode)
            } catch {
                isPipelineRunning = false
                await handle(error)
            }
        }
    }

    func runManualDictation() {
        if phase == .recording {
            finishRecording(mode: .dictation)
        } else {
            beginRecording(mode: .dictation)
        }
    }

    func runManualEditSelection() {
        if phase == .recording {
            finishRecording(mode: .editSelection)
        } else {
            beginRecording(mode: .editSelection)
        }
    }

    private func runPipeline(audioURL: URL, mode: PipelineMode) async throws {
        defer {
            activeRecordingMode = nil
            appContextAtRecordingStart = nil
            recordingStartedAt = nil
            isPipelineRunning = false
            if !config.saveAudio {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }

        let pipelineStart = Date()
        phase = .transcribing
        message = "正在本地识别"
        DictationOverlayPresenter.shared.show(message: message, phase: phase)

        let asrOptions = ASROptions(
            language: config.whisperLanguage,
            useMetal: config.whisperUseMetal,
            useCoreML: config.whisperUseCoreML,
            maxSegmentSeconds: config.whisperMaxSegmentSeconds,
            modelPath: config.whisperModelPath,
            cliCommand: config.whisperCLICommand
        )
        let asrResult = try await asrService.transcribe(audioURL: audioURL, options: asrOptions)
        let normalizedTranscript = textPolisher.polish(normalizer.normalize(asrResult.text, entries: dictionaryEntries))
        guard !normalizedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.emptyTranscript
        }

        let appContext = appContextAtRecordingStart ?? activeAppDetector.currentContext()
        let selectedText = mode == .editSelection ? selectedTextAtRecordingStart : ""
        let routedCommand = commandRouter.route(rawTranscript: normalizedTranscript, hasSelectedText: !selectedText.isEmpty)
        if routedCommand.type == .systemCommand {
            phase = .done
            message = "已取消"
            DictationOverlayPresenter.shared.hide(after: 0.5)
            return
        }
        if mode == .editSelection && selectedText.isEmpty {
            throw AppError.selectedTextUnavailable
        }
        let profile = styleProfileStore.matchProfile(
            appName: appContext.activeApp,
            bundleIdentifier: appContext.bundleIdentifier,
            profiles: styleProfiles,
            defaultProfileName: config.defaultStyleProfile
        )

        phase = .polishing
        message = "正在润色文本"
        DictationOverlayPresenter.shared.show(message: message, phase: phase)

        let action = normalizeFinalAction(await buildAction(
            mode: mode,
            rawTranscript: normalizedTranscript,
            selectedText: selectedText,
            appContext: appContext,
            styleProfile: profile
        ))

        phase = .injecting
        message = "正在插入文本"
        DictationOverlayPresenter.shared.show(message: message, phase: phase)
        try await perform(action: action, targetContext: appContext)

        let latency = Int(Date().timeIntervalSince(pipelineStart) * 1000)
        if config.saveHistory {
            try historyStore.insert(
                rawASRText: normalizedTranscript,
                finalText: action.text,
                action: action.action,
                context: appContext,
                model: LLMEndpoint.selected(from: config).model,
                asrProvider: config.asrProvider,
                llmProvider: config.llmProvider,
                latencyMs: latency
            )
            historyItems = try historyStore.recent(limit: 100)
        }

        phase = .done
        message = "完成"
        DictationOverlayPresenter.shared.hide(after: 0.8)
    }

    private func buildAction(
        mode: PipelineMode,
        rawTranscript: String,
        selectedText: String,
        appContext: ActiveAppContext,
        styleProfile: StyleProfile?
    ) async -> LLMAction {
        let endpoint = LLMEndpoint.selected(from: config)
        let keyMissing = endpoint.requiresAPIKey && apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !keyMissing, !endpoint.trimmedModel.isEmpty else {
            lastError = AppError.llmAPIKeyMissing.localizedDescription
            return PipelineFallback.actionWhenLLMUnavailable(
                mode: mode,
                transcript: rawTranscript,
                language: config.whisperLanguage
            )
        }

        do {
            let prompt = try promptBuilder.build(
                mode: mode,
                activeApp: appContext.activeApp,
                windowTitle: appContext.windowTitle,
                selectedText: selectedText,
                contextBefore: "",
                personalDictionary: dictionaryEntries,
                styleProfile: styleProfile,
                rawTranscript: rawTranscript
            )
            let result = try await llmProvider.complete(
                systemPrompt: prompt.system,
                userPrompt: prompt.user,
                options: LLMOptions(
                    model: endpoint.model,
                    temperature: endpoint.temperature,
                    timeoutSeconds: endpoint.timeoutSeconds,
                    responseFormat: "json_object"
                )
            )
            if let parsed = result.parsed {
                return parsed
            }
            return LLMAction(
                action: "show_panel",
                text: result.rawText,
                detected_language: "unknown",
                format: "plain",
                confidence: 0.4,
                warnings: ["json_parse_failed"]
            )
        } catch {
            lastError = error.localizedDescription
            return PipelineFallback.actionWhenLLMUnavailable(
                mode: mode,
                transcript: rawTranscript,
                language: config.whisperLanguage
            )
        }
    }

    private func normalizeFinalAction(_ action: LLMAction) -> LLMAction {
        let shouldNormalizeText = action.action == "insert" ||
            action.action == "replace_selection" ||
            action.action == "show_panel"
        guard shouldNormalizeText else {
            return action
        }
        let normalizedText = textPolisher.polish(normalizer.normalize(action.text, entries: dictionaryEntries))
        guard normalizedText != action.text else {
            return action
        }
        return LLMAction(
            action: action.action,
            text: normalizedText,
            detected_language: action.detected_language,
            format: action.format,
            confidence: action.confidence,
            warnings: action.warnings
        )
    }

    private func perform(action: LLMAction, targetContext: ActiveAppContext) async throws {
        if action.action == "noop" {
            return
        }
        if action.action == "show_panel" || action.confidence < 0.5 {
            ResultPanelPresenter.shared.show(text: action.text, reason: action.warnings.joined(separator: ", "))
            return
        }

        do {
            await activateTargetApp(targetContext)
            if action.action == "replace_selection" {
                try await accessibilityInjector.replaceSelectedText(action.text)
            } else {
                try await accessibilityInjector.insertText(action.text)
            }
        } catch {
            do {
                await activateTargetApp(targetContext)
                try eventTyper.type(action.text)
            } catch {
                do {
                    await activateTargetApp(targetContext)
                    if action.action == "replace_selection" {
                        try await pasteboardInjector.replaceSelectedText(action.text)
                    } else {
                        try await pasteboardInjector.insertText(action.text)
                    }
                } catch {
                    let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    ResultPanelPresenter.shared.show(text: action.text, reason: reason)
                }
            }
        }
    }

    private func activateTargetApp(_ context: ActiveAppContext) async {
        guard context.processIdentifier > 0,
              context.processIdentifier != NSRunningApplication.current.processIdentifier,
              let app = NSRunningApplication(processIdentifier: context.processIdentifier) else {
            return
        }
        app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    func clearHistory() {
        do {
            try historyStore.clear()
            historyItems = []
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshHistory() {
        historyItems = (try? historyStore.recent(limit: 100)) ?? []
    }

    private func handle(_ error: Error) async {
        phase = .error
        lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        message = lastError ?? "Error"
        DictationOverlayPresenter.shared.show(message: message, phase: phase)
        DictationOverlayPresenter.shared.hide(after: 2)
        activeRecordingMode = nil
    }
}
