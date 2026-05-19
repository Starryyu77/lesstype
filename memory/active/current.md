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

## 2026-05-19 LLM JSON 与自动插入修复

- 修复 DeepSeek / OpenAI-compatible 模型只返回 `{"action":"insert","text":"..."}` 时被严格 schema 解码拒绝的问题：`JSONRepair` 现在会对缺失字段补默认值，并只把 `text` 作为最终插入文本。
- 该问题的表象是历史记录里 `action=show_panel`，`final_text` 变成整段 JSON，因此不会进入自动插入链路。
- 剪贴板 fallback 已加固：使用 `CGEventSource(stateID: .hidSystemState)` 发送 Cmd+V，keyDown/keyUp 之间增加短延迟，恢复剪贴板前等待从 300ms 增加到 700ms。
- 新增回归测试：`JSONParsingTests.testParsesPartialActionJSONWithDefaults`。
- 验证：`swift test` 21 个 XCTest 全部通过；`bash scripts/build_app.sh debug` 成功；`codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app` 成功。
- 本机已重启为新构建版本，进程 PID：42484。

## 2026-05-19 目标 App 注入与 Toggle 模式

- 修复自动插入仍失败的主要风险：pipeline 现在会在录音开始时记录目标 App 的 `processIdentifier`，注入前重新激活该目标 App，再尝试 AX 注入和剪贴板 Cmd+V fallback。
- App 启动时不再自动弹出设置窗口，避免设置窗口抢走焦点；设置仍可从菜单栏图标打开。
- `PasteboardInjector` 在发送 Cmd+V 前会检查辅助功能权限；如果权限不足，会明确展示“需要辅助功能权限”，不再静默假装粘贴成功。
- Hotkeys 设置页已把录音模式改成中文文案，并新增“使用按一下开始/结束”按钮。
- 本机配置已切到 `hotkeyMode=toggle`：`Control+Option+A` 按一次开始录音，再按一次停止、识别并输入；`Control+Option+Shift+A` 对选中文本编辑同理。
- 当前本机仍没有有效代码签名身份：`security find-identity -v -p codesigning` 返回 `0 valid identities found`。因此当前只能 ad-hoc 签名，重打包后 TCC 权限可能反复要求重新授权。
- 验证：`swift test` 21 个 XCTest 全部通过；`bash scripts/build_app.sh debug` 成功；`codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app` 成功。
- 本机已重启为新构建版本，进程 PID：49856。

## 2026-05-19 本机开发签名路径

- 用户明确只做本机开发，不需要先购买 Apple Developer Program、Developer ID 或 notarization。
- `scripts/build_app.sh` 已改成自动优先选择本机 Keychain 里的 `Apple Development` 代码签名身份；没有时再尝试 `Developer ID Application`；都没有时才退回 ad-hoc `-`。
- README 已补充本机开发签名路径：在 Xcode 登录 Apple ID，Manage Certificates 创建 `Apple Development`，用 `security find-identity -v -p codesigning` 确认，然后直接运行 `bash scripts/build_app.sh debug`。
- 当前机器仍无有效身份，脚本验证会输出 ad-hoc fallback 提示；`codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app` 通过。
- 后续实机修复：Xcode 已创建 `Apple Development: 1873964133@qq.com (959UL4UP8J)`，但本机缺 Apple WWDR G3 中间证书，导致 `codesign` 报 `unable to build chain to self-signed root` / `errSecInternalComponent`，且 `security find-identity` 显示 0。
- 已从 Apple 官方 PKI 下载并导入 `AppleWWDRCAG3.cer` 到 login Keychain；之后 `security find-identity -v -p codesigning` 显示 1 个有效身份。
- 当前 `dist/VoiceInputMac.app` 已用 Apple Development 成功签名：`Authority=Apple Development: 1873964133@qq.com (959UL4UP8J)`，`TeamIdentifier=M58A5P2USR`；签名校验通过；本机运行 PID：83575。

## 2026-05-19 Keychain 润色前密码弹窗修复

- 用户反馈：录音结束、进入润色阶段前会要求输入密码。定位为每次 LLM 调用前 `OpenAICompatibleClient` 都读取 Keychain 中的 `custom_llm_api_key`，旧 ad-hoc 签名创建的 Keychain item 会触发访问确认。
- 修复：`OpenAICompatibleClient` 优先使用 `AppState.apiKeyDraft` 中的内存 API Key，不再每次润色前读取 Keychain；Keychain 只用于启动/设置页加载与保存。
- 修复：`KeychainStore.setSecret` 改成 delete + add，保存 API Key 时会重建 item，避免继承旧签名时期的访问控制。
- 修复：`loadSelectedAPIKeyDraft` 在成功读取非空 API Key 后会用当前 Apple Development 签名重写一次 Keychain item，迁移旧 ACL。
- 验证：`swift test` 21 个 XCTest 全部通过；`bash scripts/build_app.sh debug` 使用 `Apple Development: 1873964133@qq.com (959UL4UP8J)` 成功签名；`codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app` 通过；本机运行 PID：88466。

## 2026-05-19 Toggle 与粘贴插入修复

- 用户反馈：目标是按一次开始、再按一次结束，但实际仍像按住说话；且历史里有内容但不能正常自动插入。
- 根因一：Toggle 模式下仍启用了基础 VAD，持续静音检测会提前结束录音，导致长句被切成短片段。已关闭当前录音链路中的 VAD 自动结束，Toggle 现在必须第二次按键才停止；最大录音时长到达时才自动收尾。
- 根因二：录音浮窗文案仍写“松开以输入”。已根据 `hotkeyMode` 显示“再按一次以输入 / 再按一次以替换”。
- 插入增强：`PasteboardInjector` 会先通过 Accessibility 找目标 App 菜单中的 Paste/粘贴/貼上 项并执行 AXPress；找不到或失败才 fallback 到 CGEvent Cmd+V。对部分 App，会先打开 Edit/编辑/編輯 菜单再查找 Paste。
- 验证：`swift test` 21 个 XCTest 全部通过；`bash scripts/build_app.sh debug` 使用 Apple Development 成功签名；`codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app` 通过；本机运行 PID：95915。

## 2026-05-19 润色强度与同音误识别修复

- 用户反馈：“差路”应为“插入”，且 App 对口语内容的整理不够主动。
- 新增默认词典与迁移：`插入` written 形式，aliases=`差路/叉入/插路`；已有数据库会补齐缺失默认项。本机 SQLite 已确认写入 id=8。
- `DictionaryNormalizer` 新增后处理：纠正 `差路/叉入/插路 -> 插入`，并压缩 `去进行一个整理/进行一个整理 -> 整理`、`没有办法去 -> 无法` 等拖沓口语结构。
- LLM 返回后，`AppState` 会对 `insert` / `replace_selection` 的最终文本再跑一次词典和口语后处理，避免模型漏改。
- `polish.zh.md` prompt 加强：要求主动轻度书面化整理、修正明显同音错字、删除“这个/进行一个/还有一个问题就是”等拖沓结构，并加入 “差路 -> 插入” 的示例。
- 剪贴板恢复等待从 700ms 提高到 1500ms，降低 Electron/异步读取剪贴板的 App 粘贴失败概率。
- 验证：`swift test` 22 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：3089。
- 追加修复：用户继续反馈模型只是加标点，没有真正重组句子。`polish.zh.md` 已把默认策略从“轻度书面化整理”升级为“可读文本重写”，要求合并/拆分/调换短句、合并重复判断、整理原因和转折，并加入完整反馈句示例。
- 新增 `DictationTextPolisher` 本地兜底，专门处理“识别正常但插入/整理不正常”“没有把我说的话重新整理”等高频反馈句，把它们改写为更自然的表达。
- 验证：`swift test` 23 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：10380。
- 追加修复：用户澄清“前面说整理正常，后面又说整理不正常”属于后续修正，最终文本应删除前面的旧判断而不是并列矛盾。`polish.zh.md` 新增“后续修正只保留最新判断”规则和示例；`DictationTextPolisher` 新增移除被推翻的“整理正常”判断规则。
- 验证：`swift test --filter DictationTextPolisherTests` 通过；`swift test` 24 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：17193。

## 2026-05-19 润色收敛、录音时长、动画与插入修复

- 用户反馈润色过度：现在默认策略改为“结构化整理”，保留原表达，不擅自添加内容、解释或扩句；仍保留后续修正规则，例如前面说“整理正常”、后面改口“整理不正常”时删除旧判断。
- Toggle 模式取消 30 秒自动停止：`AudioRecorder` 在 `maxDurationSeconds <= 0` 时不再创建自动停止 timer；`AppState` 在 Toggle 模式下传入 `0`，Press-to-talk 仍保留配置时长保护。
- Overlay 增加动画：录音时显示随麦克风音量变化的语音条；本地识别、润色、插入阶段显示对应处理动画。
- 自动插入 fallback 顺序调整为：Accessibility 直接写入 -> CGEvent Unicode 直接键入 -> Pasteboard/菜单粘贴 -> ResultPanel，避免剪贴板事件“已发送但目标 App 没有真正粘贴”时过早判定成功。
- 验证：`swift test` 24 个 XCTest 全部通过；`bash scripts/build_app.sh debug` 使用 `Apple Development: 1873964133@qq.com (959UL4UP8J)` 成功签名；`codesign --verify --deep --strict --verbose=2 dist/VoiceInputMac.app` 通过；本机运行 PID：30413。

## 2026-05-19 插入链路继续加固

- 用户测试后反馈插入仍有问题。继续修复 `AccessibilityInjector`：优先使用 `AXValue + AXSelectedTextRange` 按真实光标/选区替换文本，写入后重新读取 `AXValue` 验证，避免 AX API 返回成功但目标输入框没有实际接收时误判成功。
- `CGEventTyper` 改为按 UTF-16 chunk 发送 Unicode 文本，并在 keyDown/keyUp 和 chunk 之间加入短延迟，降低目标 App 丢字风险。
- 目标 App 重新激活增强：使用 `.activateIgnoringOtherApps + .activateAllWindows`，等待时间提高到 300ms。
- 新增 `AccessibilityInjectorTests` 覆盖光标插入、选区替换、非法 range。
- 验证：`swift test` 27 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：38199。

## 2026-05-19 辅助功能 TCC 重新绑定

- 用户截图显示：系统设置中 VoiceInputMac 辅助功能开关为开启，但 App 结果面板仍提示辅助功能未授权。判断为当前 bundle id 的 TCC 记录与正在运行的签名构建未正确绑定。
- 新增 `AccessibilityPermission`：统一使用 `AXIsProcessTrustedWithOptions`，在启动和插入/选区读取路径上允许系统弹出辅助功能授权提示。
- 权限页新增“请求辅助功能权限”按钮；辅助功能错误文案改为说明“关闭再打开/删除重加 dist/VoiceInputMac.app/重启 App”的恢复动作。
- 已执行 `tccutil reset Accessibility local.voiceinputmac.app`，只重置 VoiceInputMac 这一条辅助功能记录；随后重启 App 并打开辅助功能设置页，等待用户重新启用当前构建。
- 验证：`swift test` 27 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：48928。

## 2026-05-19 重复插入修复

- 用户反馈：辅助功能重新绑定后可以插入，但一次插入多遍。
- 修复 `CGEventTyper`：Unicode 文本只放在 keyDown 事件，keyUp 不再携带同一段文本，避免部分目标 App 同时消费 keyDown/keyUp 导致重复插入。
- `AppState` 增加 `isPipelineRunning` 防重入锁，避免同一次录音结果被重复执行 pipeline/插入。
- 验证：`swift test` 27 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：53712。
- 追加定位：历史表最近记录 `final_text` 只有一遍，但输入框出现约 6 遍；这与 `AccessibilityInjector` 的 6 次重试吻合。原因是 AX 写入已经成功，但写后读取验证拿不到新值，导致误判失败并重复写入。已移除写后验证，`AXUIElementSetAttributeValue(kAXValueAttribute)` 成功后立即返回。
- 验证：`swift test` 27 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：58841。

## 2026-05-19 热键录制设置

- 用户要求：设置页中的热键管理应允许用户自己设置热键，而不是只用固定预设或手动输入字符串。
- `HotkeySettingsView` 新增热键录制控件：点击“录制”后按新的组合键即可保存；按 Esc 取消；录制时暂停当前全局热键监听，避免设置过程中误触发录音。
- `HotKeyDefinition` 新增从 `NSEvent` 构造热键、规范化显示名、F1-F20、数字键、方向键、Delete 与 `KeyNN` 解析。
- `AppState` 新增 `assignHotkey`、冲突检查和热键设置状态提示；保存后立即重新注册全局热键。
- 验证：`swift test` 29 个 XCTest 全部通过；Apple Development 签名构建和 `codesign --verify` 通过；本机运行 PID：67570。
