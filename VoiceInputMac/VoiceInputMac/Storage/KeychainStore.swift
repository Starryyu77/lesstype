import Foundation
import Security

final class KeychainStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func setSecret(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw AppError.llmFailed("Keychain replace failed: \(deleteStatus)")
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrLabel as String] = "VoiceInputMac API Key"
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AppError.llmFailed("Keychain save failed: \(addStatus)")
        }
    }

    func getSecret(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw AppError.llmFailed("Keychain read failed: \(status)")
        }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
