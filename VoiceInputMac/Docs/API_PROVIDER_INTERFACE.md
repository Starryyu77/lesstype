# 自定义 API 接入接口

VoiceInputMac 的第一版音频链路是：

```text
麦克风音频 -> 本地 whisper.cpp ASR -> 文本 -> 文本 LLM 润色/改写 -> 文本注入
```

因此自定义 API 接口默认接的是“文本 LLM”，不是语音大模型。

## 什么时候需要语音大模型

只有在你想把音频直接发给 API，让服务同时做 ASR、理解和改写时，才需要语音大模型或多模态语音模型。当前隐私目标是默认音频不上云，所以第一版不走这个方向。

## 推荐接口

实现一个 OpenAI-compatible `chat/completions` 接口即可：

```http
POST /v1/chat/completions
Content-Type: application/json
Authorization: Bearer <optional-api-key>
```

请求体：

```json
{
  "model": "your-model",
  "temperature": 0.2,
  "response_format": {"type": "json_object"},
  "messages": [
    {"role": "system", "content": "system prompt"},
    {"role": "user", "content": "user prompt"}
  ]
}
```

响应体：

```json
{
  "choices": [
    {
      "message": {
        "content": "{\"action\":\"insert\",\"text\":\"最终文本\",\"detected_language\":\"zh\",\"format\":\"plain\",\"confidence\":0.9,\"warnings\":[]}"
      }
    }
  ]
}
```

`content` 最好直接是合法 JSON 字符串，字段符合：

```json
{
  "action": "insert | replace_selection | show_panel | noop",
  "text": "最终要插入或展示的文本",
  "detected_language": "zh | en | mixed | unknown",
  "format": "plain | markdown | email | message | code_comment",
  "confidence": 0.0,
  "warnings": []
}
```

## App 设置

在 LLM 设置页选择：

```text
Provider = 自定义 OpenAI-compatible
Base URL = http://127.0.0.1:8000/v1
Path = chat/completions
Model = your-model
```

如果你的服务不需要鉴权：

```text
需要 API Key = off
```

如果你的服务需要 `Authorization: Bearer xxx`：

```text
需要 API Key = on
Auth Header = Authorization
Auth Scheme = Bearer
```

如果你的服务需要 `X-API-Key: xxx`：

```text
需要 API Key = on
Auth Header = X-API-Key
Auth Scheme =
```

API Key 仍保存到 macOS Keychain，不写入配置文件。
不要把 token、secret、Authorization、X-API-Key 这类敏感值放进 Extra Headers JSON；需要鉴权时用 API Key 输入框和 Auth Header / Auth Scheme。

## 不建议的接口

不建议第一版接入“上传音频给云端语音大模型”的接口，因为这会改变隐私承诺：

- 音频不再只在本地处理。
- 需要额外的音频上传权限与数据留存说明。
- 错误边界从文本润色扩展到 ASR、说话人、噪声、语种识别等更多环节。

如果后续确实需要，可以新增单独的 `CloudSpeechProvider`，并在设置里显式标记“会上传音频”。
