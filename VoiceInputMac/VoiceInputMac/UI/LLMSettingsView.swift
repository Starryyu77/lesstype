import SwiftUI

struct LLMSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        SettingsPage(
            title: "文本模型",
            subtitle: "只发送识别后的文本，用于轻度整理和选中文本改写。",
            systemImage: "sparkles"
        ) {
            SettingsPanel("Provider", subtitle: "内置火山方舟，也可以接入自己的 OpenAI-compatible 服务。") {
                SettingsRow("当前接口", detail: "切换后会使用对应的 Keychain 账号读取 API Key。") {
                    Picker("", selection: providerBinding) {
                        ForEach(LLMProviderID.allCases) { provider in
                            Text(provider.title).tag(provider.rawValue)
                        }
                    }
                    .labelsHidden()
                }
            }

            if selectedProvider == .volcengineArk {
                SettingsPanel("豆包 / 火山方舟") {
                    SettingsRow("Base URL") {
                        TextField("https://ark.cn-beijing.volces.com/api/v3", text: binding(\.arkBaseURL))
                            .textFieldStyle(.roundedBorder)
                    }
                    SettingsDivider()
                    SettingsRow("Model", detail: "不在代码里硬编码，按你的方舟模型配置填写。") {
                        TextField("model", text: binding(\.arkModel))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            } else {
                SettingsPanel("自定义 OpenAI-compatible API", subtitle: "服务只需要实现 /chat/completions，返回 choices[0].message.content。") {
                    SettingsRow("Base URL") {
                        TextField("http://127.0.0.1:8000/v1", text: binding(\.customLLMBaseURL))
                            .textFieldStyle(.roundedBorder)
                    }
                    SettingsDivider()
                    SettingsRow("Path") {
                        TextField("chat/completions", text: binding(\.customLLMPath))
                            .textFieldStyle(.roundedBorder)
                    }
                    SettingsDivider()
                    SettingsRow("Model") {
                        TextField("model", text: binding(\.customLLMModel))
                            .textFieldStyle(.roundedBorder)
                    }
                    SettingsDivider()
                    SettingsRow("需要 API Key") {
                        Toggle("", isOn: binding(\.customLLMRequiresAPIKey))
                            .labelsHidden()
                    }
                    SettingsDivider()
                    SettingsRow("Auth Header") {
                        TextField("Authorization", text: binding(\.customLLMAuthHeader))
                            .textFieldStyle(.roundedBorder)
                    }
                    SettingsDivider()
                    SettingsRow("Auth Scheme") {
                        TextField("Bearer", text: binding(\.customLLMAuthScheme))
                            .textFieldStyle(.roundedBorder)
                    }
                    SettingsDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extra Headers JSON")
                            .font(.body)
                        TextField("{}", text: binding(\.customLLMExtraHeadersJSON), axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            SettingsPanel("调用参数") {
                SettingsRow("API Key", detail: "保存到 macOS Keychain，不写入配置文件。") {
                    SecureField("API Key", text: $appState.apiKeyDraft)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("Temperature", detail: "语音输入建议低温，避免自由发挥。") {
                    HStack(spacing: 8) {
                        Slider(value: binding(\.arkTemperature), in: 0...1)
                        Text(appState.config.arkTemperature.formatted(.number.precision(.fractionLength(2))))
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }
                SettingsDivider()
                SettingsRow("Timeout") {
                    Stepper("\(appState.config.arkTimeoutSeconds) 秒", value: binding(\.arkTimeoutSeconds), in: 5...120)
                }
            }

            SettingsPanel("连接") {
                HStack(spacing: 10) {
                    Button {
                        appState.saveAPIKey()
                    } label: {
                        Label("保存到 Keychain", systemImage: "key")
                    }
                    Button {
                        appState.testLLMConnection()
                    } label: {
                        Label("测试连接", systemImage: "network")
                    }
                    Button {
                        appState.saveConfig()
                    } label: {
                        Label("保存设置", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                }
                if !appState.llmCheckMessage.isEmpty {
                    Text(appState.llmCheckMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
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
