# lesstype

本仓库维护一个本地优先的 macOS AI 语音输入助手。当前实现位于 [`VoiceInputMac/`](VoiceInputMac/)。

核心目标：

- macOS 原生菜单栏 App，不使用 Electron / Tauri / Web 套壳。
- `Option+Space` 按住录音，松开后本地 ASR、LLM 润色并插入当前输入框。
- 默认音频不上云，第一版使用 whisper.cpp CLI 在本地识别。
- 只把识别后的文本发送到豆包 / 火山方舟 OpenAI-compatible API 做润色。
- API Key 存入 macOS Keychain。
- 历史、词典、风格配置保存在本地 SQLite。

## 当前状态

第一版 MVP 已实现并通过本地测试：

```bash
cd VoiceInputMac
swift test
```

也支持生成开发版 `.app`：

```bash
cd VoiceInputMac
bash scripts/build_app.sh debug
open dist/VoiceInputMac.app
```

详细说明见 [`VoiceInputMac/README.md`](VoiceInputMac/README.md)。

## 隐私边界

- 默认不上传音频。
- 默认不保存音频，临时 WAV 识别完成后删除。
- 默认不做遥测。
- API Key 不写入日志，不明文保存。
- 本地历史可以关闭或清空。
