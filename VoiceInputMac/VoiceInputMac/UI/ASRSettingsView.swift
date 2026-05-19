import SwiftUI

struct ASRSettingsView: View {
    @ObservedObject var appState: AppState
    private let manager = WhisperModelManager()

    var body: some View {
        Form {
            TextField("ASR Provider", text: binding(\.asrProvider))
            Picker("Whisper 模型", selection: binding(\.whisperModel)) {
                ForEach(WhisperModelManager.supportedModels, id: \.self) { model in
                    Text(manager.displayName(for: model)).tag(model)
                }
            }
            TextField("模型路径", text: binding(\.whisperModelPath))
            TextField("whisper-cli 命令", text: binding(\.whisperCLICommand))
            Picker("语言", selection: binding(\.whisperLanguage)) {
                Text("zh").tag("zh")
                Text("en").tag("en")
                Text("auto").tag("auto")
            }
            Toggle("启用 Metal", isOn: binding(\.whisperUseMetal))
            Toggle("启用 Core ML", isOn: binding(\.whisperUseCoreML))
            Toggle("启用 VAD", isOn: binding(\.whisperEnableVAD))
            Stepper("最大录音时长：\(appState.config.whisperMaxSegmentSeconds) 秒", value: binding(\.whisperMaxSegmentSeconds), in: 5...300)

            if !appState.config.whisperModelPath.isEmpty && !manager.validateModelPath(appState.config.whisperModelPath) {
                Label("未找到 Whisper 模型文件。请检查模型路径。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            HStack {
                Button("检查 ASR 配置") {
                    appState.validateASRSetup()
                }
                Button("保存 ASR 设置") {
                    appState.saveConfig()
                }
            }

            if !appState.asrCheckMessage.isEmpty {
                Text(appState.asrCheckMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
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
