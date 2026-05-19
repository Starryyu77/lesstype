# VoiceInputMac 当前任务记忆

- 项目：本地优先 macOS 菜单栏 AI 语音输入助手。
- 当前阶段：从零实现第一版 MVP。
- 技术边界：SwiftUI + AppKit + AVAudioEngine + whisper.cpp CLI + OpenAI-compatible Ark API + SQLite + Keychain。
- 隐私边界：默认音频不上云，默认不保存音频，API Key 只进 Keychain，不做遥测。
- 当前实现目录：`/Users/starryyu/2026/lesstype/VoiceInputMac`。
- 验证：`swift test` 已通过，11 个 XCTest 全部通过。

## 2026-05-19 自定义 API 与后续补齐

- 新增显式自定义文本 LLM 接口：`custom_openai_compatible`，配置项包括 `baseURL`、`path`、`model`、`authHeader`、`authScheme`、是否需要 API Key、extra headers JSON。
- 新增接口文档：`VoiceInputMac/Docs/API_PROVIDER_INTERFACE.md`。
- LLM 调用已从方舟专用 `ArkClient` 切到通用 `OpenAICompatibleClient`；火山方舟现在是内置 OpenAI-compatible endpoint，自定义 API 是第二个 endpoint。
- API Key 仍保存到 Keychain，账号按 endpoint 区分：`ark_api_key` / `custom_llm_api_key`。
- 新增 AppConfig 兼容解码，后续新增配置字段不会导致旧本地配置整体解码失败。
- Toggle 快捷键模式已接入 `HotKeyManager`；基础 VAD 自动结束已接入 `AudioRecorder`，当前只在 Toggle 模式下启用，避免打断 Press-to-talk。
- 验证：`swift test` 已通过，14 个 XCTest 全部通过。
- 打包：`bash scripts/build_app.sh debug` 成功，`codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app` 成功。
- 架构判断：当前阶段不需要语音大模型；本地 whisper.cpp 已负责 ASR，远端/自定义 API 只需要普通文本 LLM。只有改成“上传音频给 API 做 ASR+理解+改写”时才需要语音大模型。
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

## 2026-05-19 本机调试修复

- 修复录音后闪退：`AudioRecorder` 不再在 CoreAudio 实时 tap 线程中用 `AVAudioFile.write` 转换/写 WAV，改为收集 mono float samples，停止录音后离线写 16kHz mono PCM16 WAV。
- 修复 whisper.cpp backend 日志被插入：`WhisperCliService` 成功路径优先使用 `-otxt -of` 生成的 transcript 文件，不再在 stdout 为空时把 stderr 当作 ASR 文本；`clean` 也会过滤 `load_backend:`、`ggml_`、`whisper_` 等诊断行。
- 修复“没有有效输入内容”误导：本机之前配置的是 Homebrew 的 `for-tests-ggml-tiny.bin` 空测试模型，`whisper-cli` 输出 `WARN no tensors loaded from model file - assuming empty model for testing`；现在 `WhisperCliService` 会把这种情况提示为模型不可用。
- 已下载真实多语言模型 `VoiceInputMac/Models/ggml-small.bin`（gitignore，不提交），并把本机配置更新为 `whisperModel=small`、`whisperModelPath=/Users/starryyu/2026/lesstype/VoiceInputMac/Models/ggml-small.bin`、`whisperLanguage=zh`。
- 已用 `whisper-cli` 验证：`ggml-small.bin` 可转写 Homebrew `jfk.wav`，也可转写本机 `say -v Tingting` 生成的中文 WAV。
- 新增回归测试：`AudioBufferWriterTests` 与 `WhisperCliServiceTests`。
- 本机当前运行修复版：`dist/VoiceInputMac.app`，最近验证 `swift test` 20 个 XCTest 全部通过。
- 权限反复请求的原因：本机 `security find-identity -v -p codesigning` 返回 0 个有效身份，当前只能 ad-hoc 签名；每次重新打包可能改变 TCC 识别，长期使用需要稳定 Apple Development / Developer ID 签名或固定使用同一个已授权 `.app`。
