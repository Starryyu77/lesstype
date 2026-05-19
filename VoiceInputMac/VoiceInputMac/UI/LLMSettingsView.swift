import SwiftUI

struct LLMSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Picker("Provider", selection: providerBinding) {
                ForEach(LLMProviderID.allCases) { provider in
                    Text(provider.title).tag(provider.rawValue)
                }
            }

            if selectedProvider == .volcengineArk {
                Section("豆包 / 火山方舟") {
                    TextField("Base URL", text: binding(\.arkBaseURL))
                    TextField("Model", text: binding(\.arkModel))
                }
            } else {
                Section("自定义 OpenAI-compatible API") {
                    TextField("Base URL", text: binding(\.customLLMBaseURL))
                    TextField("Path", text: binding(\.customLLMPath))
                    TextField("Model", text: binding(\.customLLMModel))
                    Toggle("需要 API Key", isOn: binding(\.customLLMRequiresAPIKey))
                    TextField("Auth Header", text: binding(\.customLLMAuthHeader))
                    TextField("Auth Scheme", text: binding(\.customLLMAuthScheme))
                    TextField("Extra Headers JSON", text: binding(\.customLLMExtraHeadersJSON), axis: .vertical)
                        .lineLimit(2...4)
                    Text("你的服务只需要实现 OpenAI-compatible /chat/completions，返回 choices[0].message.content。content 应尽量是本 App 要求的 JSON。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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

    private var selectedProvider: LLMProviderID {
        LLMProviderID(rawValue: appState.config.llmProvider) ?? .volcengineArk
    }

    private var providerBinding: Binding<String> {
        Binding(
            get: { appState.config.llmProvider },
            set: { appState.selectLLMProvider($0) }
        )
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
