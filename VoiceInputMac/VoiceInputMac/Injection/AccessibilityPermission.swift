import ApplicationServices
import Foundation

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static var recoveryMessage: String {
        "当前构建还没有获得可用的辅助功能权限。请在系统设置 -> 隐私与安全性 -> 辅助功能中把 VoiceInputMac 关闭再打开；如果仍不生效，请删除该条目后重新添加 dist/VoiceInputMac.app，然后重启 App。"
    }
}
