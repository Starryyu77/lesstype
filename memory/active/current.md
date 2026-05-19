# VoiceInputMac 当前任务记忆

- 项目：本地优先 macOS 菜单栏 AI 语音输入助手。
- 当前阶段：从零实现第一版 MVP。
- 技术边界：SwiftUI + AppKit + AVAudioEngine + whisper.cpp CLI + OpenAI-compatible Ark API + SQLite + Keychain。
- 隐私边界：默认音频不上云，默认不保存音频，API Key 只进 Keychain，不做遥测。
- 当前实现目录：`/Users/starryyu/2026/lesstype/VoiceInputMac`。
- 验证：`swift test` 已通过，11 个 XCTest 全部通过。
- 第一版已覆盖：Package.swift、README、.env.example、Prompt 文件、默认词典/风格、菜单栏 App、设置页、AVAudioEngine 录音、whisper.cpp CLI ASR、Ark LLM 客户端、Keychain、SQLite、剪贴板注入、AX 读取/写入尝试、命令规则路由、测试用例。
- 明确未完成：whisper.cpp C API / XCFramework 常驻模型、Core ML/ANE、完整 VAD、notarization、真实 GUI 权限启动验证。

## 2026-05-19 继续实现

- 新增开发版 `.app` 打包支持：`Support/Info.plist`、`Support/VoiceInputMac.entitlements`、`scripts/build_app.sh`。
- 打包输出：`/Users/starryyu/2026/lesstype/VoiceInputMac/dist/VoiceInputMac.app`。
- `.app` 已通过 `codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app`。
- Prompt 资源加载已改为优先读 `.app/Contents/Resources/VoiceInputMac_VoiceInputMac.bundle`，避免把资源 bundle 放在 `.app` 根目录导致签名失败。
- 设置页增强：ASR 配置检查、LLM 测试连接、词典选择/修改/保存、Style Profile 选择/修改/新增/删除。
- 快捷键增强：`HotKeyManager` 从配置解析 `Option+Space` / `Option+Shift+Space` 等组合键，不再只硬编码默认值。
- 验证：`swift test` 已通过，11 个 XCTest 全部通过。
