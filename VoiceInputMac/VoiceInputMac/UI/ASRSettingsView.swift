import SwiftUI

struct ASRSettingsView: View {
    @ObservedObject var appState: AppState
    private let manager = WhisperModelManager()

    private var modelPathOK: Bool {
        appState.config.whisperModelPath.isEmpty || manager.validateModelPath(appState.config.whisperModelPath)
    }

    var body: some View {
        SettingsPage(
            title: "本地识别",
            subtitle: "Whisper.cpp CLI 负责本地 ASR，音频默认不上传。",
            systemImage: "waveform"
        ) {
            SettingsPanel("Whisper 模型", subtitle: "M4 + 24GB 内存可以优先用 large-v3-turbo；测试时 small 更快。") {
                SettingsRow("ASR Provider", detail: "第一版固定为本地 Whisper。") {
                    TextField("", text: binding(\.asrProvider))
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("模型", detail: "切换模型后会影响识别速度和准确率。") {
                    Picker("", selection: binding(\.whisperModel)) {
                        ForEach(WhisperModelManager.supportedModels, id: \.self) { model in
                            Text(manager.displayName(for: model)).tag(model)
                        }
                    }
                    .labelsHidden()
                }
                SettingsDivider()
                SettingsRow("模型路径", detail: "必须指向本地 ggml 模型文件。") {
                    TextField("ggml-large-v3-turbo.bin", text: binding(\.whisperModelPath))
                        .textFieldStyle(.roundedBorder)
                }
                if !modelPathOK {
                    SettingsStatusLabel(text: "未找到 Whisper 模型文件", systemImage: "exclamationmark.triangle", tone: .danger)
                }
            }

            SettingsPanel("运行参数") {
                SettingsRow("whisper-cli", detail: "可填写命令名或完整路径。") {
                    TextField("whisper-cli", text: binding(\.whisperCLICommand))
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("语言", detail: "中文听写建议 zh；混合内容可设 auto。") {
                    Picker("", selection: binding(\.whisperLanguage)) {
                        Text("zh").tag("zh")
                        Text("en").tag("en")
                        Text("auto").tag("auto")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                SettingsDivider()
                SettingsRow("最大录音时长", detail: "Toggle 模式不会用 30 秒强制截断。") {
                    Stepper("\(appState.config.whisperMaxSegmentSeconds) 秒", value: binding(\.whisperMaxSegmentSeconds), in: 5...300)
                }
            }

            SettingsPanel("加速与分段") {
                SettingsRow("Metal", detail: "M 系列 Mac 建议开启。") {
                    Toggle("", isOn: binding(\.whisperUseMetal))
                        .labelsHidden()
                }
                SettingsDivider()
                SettingsRow("Core ML", detail: "第二阶段能力，MVP 可保持关闭。") {
                    Toggle("", isOn: binding(\.whisperUseCoreML))
                        .labelsHidden()
                }
                SettingsDivider()
                SettingsRow("VAD", detail: "语音活动检测，当前作为体验优化开关保留。") {
                    Toggle("", isOn: binding(\.whisperEnableVAD))
                        .labelsHidden()
                }
            }

            SettingsPanel("检查") {
                HStack(spacing: 10) {
                    Button {
                        appState.validateASRSetup()
                    } label: {
                        Label("检查 ASR 配置", systemImage: "checkmark.seal")
                    }
                    Button {
                        appState.saveConfig()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                }
                if !appState.asrCheckMessage.isEmpty {
                    Text(appState.asrCheckMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppConfig, Value>) -> Binding<Value> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: {
                appState.config[keyPath: keyPath] = $0
                appState.saveConfig()
            }
        )
    }
}
