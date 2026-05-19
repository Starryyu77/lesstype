import SwiftUI

struct LLMSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            TextField("Provider", text: binding(\.llmProvider))
            TextField("Base URL", text: binding(\.arkBaseURL))
            TextField("Model", text: binding(\.arkModel))
            SecureField("API Key", text: $appState.apiKeyDraft)
            HStack {
                Text("Temperature")
                Slider(value: binding(\.arkTemperature), in: 0...1)
                Text(appState.config.arkTemperature.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            Stepper("Timeout：\(appState.config.arkTimeoutSeconds) 秒", value: binding(\.arkTimeoutSeconds), in: 5...120)

            HStack {
                Button("保存到 Keychain") {
                    appState.saveAPIKey()
                }
                Button("测试连接") {
                    appState.testLLMConnection()
                }
                Button("保存 LLM 设置") {
                    appState.saveConfig()
                }
            }

            if !appState.llmCheckMessage.isEmpty {
                Text(appState.llmCheckMessage)
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
