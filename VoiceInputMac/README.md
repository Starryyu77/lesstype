# VoiceInputMac

本项目是一个本地优先的 macOS 菜单栏 AI 语音输入助手。它不是传统 IME，也不依赖 Electron / Tauri / WebView。第一版目标是跑通：

`Option+Space 按住录音 -> 本地 whisper.cpp CLI ASR -> 豆包 / 火山方舟文本润色 -> 剪贴板 + Cmd+V 插入 -> SQLite 本地历史`

项目从产品需求重新实现，不逆向、复制或引用任何第三方私有代码、素材、UI 资产、商业文案或专有实现。

## 已实现范围

- SwiftUI + AppKit 菜单栏 App。
- 设置页：General、ASR、LLM、Hotkeys、Dictionary、History、Styles、Permissions。
- `Option+Space` 普通听写，`Option+Shift+Space` 选中文本编辑指令。
- AVAudioEngine 录音，输出 16kHz mono PCM WAV 临时文件。
- whisper.cpp CLI ASR：默认本地模型，默认不上传音频。
- OpenAI-compatible Ark 客户端：base URL、model、temperature、timeout 可配置。
- API Key 存入 macOS Keychain。
- Prompt 文件与 JSON schema 解析 / 修复。
- 个人词典与 App 风格 profile。
- 剪贴板 + Cmd+V 注入 fallback，并尽量恢复原剪贴板。
- Accessibility 注入尝试与选中文本读取。
- SQLite 历史记录，默认保存文本历史，默认不保存音频。
- 插入失败时显示可复制结果浮窗。

## 尚未完成

- whisper.cpp C API / XCFramework 常驻模型集成。
- large-v3-turbo 自动下载与模型管理 UI。
- Core ML / ANE 加速。
- 动态快捷键重绑定。
- 更完整的 VAD 自动结束。
- 更可靠的 AX 文本范围替换。
- API 测试连接按钮的真实端到端测试。
- App bundle / codesign / notarization 发布配置。

## 环境要求

- macOS 13 或更高。
- Apple Silicon Mac，推荐 M4 / 24GB unified memory。
- Xcode Command Line Tools。
- whisper.cpp 已安装并能调用 `whisper-cli`。
- 本地 Whisper 模型文件，例如 `ggml-large-v3-turbo.bin`。

## 构建

```bash
cd /Users/starryyu/2026/lesstype/VoiceInputMac
swift build
```

运行：

```bash
swift run VoiceInputMac
```

开发期通过 Swift Package 运行时，系统权限可能显示为 Terminal / SwiftPM 进程。正式长期使用建议后续阶段生成 `.app` bundle 并签名。

生成开发版 `.app`：

```bash
cd /Users/starryyu/2026/lesstype/VoiceInputMac
bash scripts/build_app.sh debug
open dist/VoiceInputMac.app
```

`.app` 的 `Info.plist` 已声明麦克风用途，并设置为菜单栏常驻应用。第一次运行后，在系统设置里给 `VoiceInputMac.app` 授权麦克风、辅助功能和输入监听。

## whisper.cpp 准备

示例方式：

```bash
brew install whisper-cpp
```

确认 CLI 可用：

```bash
whisper-cli --help
```

在设置页中配置：

- Whisper 模型：默认 `large-v3-turbo`
- 模型路径：你的本地 `ggml-*.bin` 文件路径
- 语言：`zh` / `en` / `auto`
- Metal：默认开启

如果模型路径为空或文件不存在，App 会提示“未找到 Whisper 模型文件”。

## 豆包 / 火山方舟配置

在设置页 LLM 中配置：

- Base URL：默认 `https://ark.cn-beijing.volces.com/api/v3`
- Model：填入你的方舟模型名
- API Key：输入后点击“保存到 Keychain”
- Temperature：默认 `0.2`
- Timeout：默认 `20` 秒

没有 API Key 或模型名时，App 不会调用 LLM，会直接插入本地 ASR 文本。

## 快捷键

- `Option+Space`：按住说话，松开后识别并插入。
- `Option+Shift+Space`：按住说编辑指令，松开后改写当前选中文本。

第一版内置监听这两个组合键。设置页会持久化快捷键文本，但动态重绑定放在阶段 2。

## 权限说明

需要的 macOS 权限：

- 麦克风：录音。
- 辅助功能：读取选中文本、尝试写入当前输入框、模拟粘贴。
- 输入监听：全局按住说话快捷键在部分系统上需要。

设置页 `Permissions` 提供系统设置入口。

## 隐私说明

- 默认音频只在本地处理。
- 默认不保存音频，临时 WAV 在识别完成后删除。
- 只有识别后的文本会发送给豆包 / 火山方舟做润色。
- API Key 存入 macOS Keychain。
- 不做遥测。
- 不上传音频。
- 日志和错误信息不得输出 Authorization header 或 API Key。
- 历史只保存在本机 SQLite，用户可关闭或清空。

## 本地数据

SQLite 默认位置：

```text
~/Library/Application Support/VoiceInputMac/VoiceInputMac.sqlite3
```

包含：

- `dictionary_entries`
- `style_profiles`
- `history`
- `app_settings`

## 常见问题

### 无法录音

检查麦克风权限。开发期 `swift run` 可能请求的是 Terminal 的麦克风权限。

### 无法插入文本

检查辅助功能权限和输入监听权限。若自动插入失败，结果会显示在浮窗里，可手动复制。

### 模型找不到

在 ASR 设置里填写完整模型路径，例如 `/Users/you/Models/ggml-large-v3-turbo.bin`。

### 豆包调用失败

检查 Base URL、Model、API Key 和网络。HTTP 错误会显示状态码，但不会打印 API Key。

### 剪贴板没有恢复

第一版会保存并恢复 NSPasteboard item。某些 App 在粘贴时可能异步读取剪贴板，可把恢复等待时间在后续阶段做成设置。

### 识别太慢

第一版使用 whisper.cpp CLI，每次调用都可能加载模型。阶段 2 会改成 C API / XCFramework 并常驻模型。

### 识别不准

优先使用 `large-v3-turbo` 或 `large-v3`，确认输入为清晰中文，必要时在词典中加入项目名、人名、技术术语。

## 开发路线图

### 阶段 1：MVP

当前实现基本覆盖：菜单栏、设置、录音、WAV、whisper.cpp CLI、Ark 润色、剪贴板注入、SQLite 历史、默认不保存音频。

### 阶段 2：体验优化

- 接入 whisper.cpp C API / XCFramework。
- App 启动后预加载模型。
- 录音、识别、润色、插入状态更完整。
- 基础 VAD 自动结束。
- 模型切换与性能提示。
- API 测试连接。

### 阶段 3：Mac 深度集成

- 更可靠的 Accessibility 读写。
- 更完整的选中文本编辑。
- 根据当前 App 自动选择风格。
- 动态快捷键设置。
- 权限引导完善。

### 阶段 4：性能和可靠性

- WhisperBenchmark。
- Core ML 可选加速。
- 长文本分段。
- 更稳的 LLM 超时与重试。
- 历史和词典搜索增强。
- 日志分级与隐私审计。
