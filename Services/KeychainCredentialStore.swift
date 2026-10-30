import Foundation
import Security

/// Keeps the last-used e-mail and password in the Keychain so Face ID can sign in again
/// after the user has explicitly signed out. Encrypted by iOS, this-device-only, never synced.
nonisolated struct KeychainCredentialStore: Sendable {
    struct Credentials: Sendable { let email: String; let password: String }

    private let service = "com.lozaa.CivicFix.credentials"
    private let account = "primary"

    func save(email: String, password: String) {
        let payload = [email, password].joined(separator: "\n")
        guard let data = payload.data(using: .utf8) else { return }
        clear()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func load() -> Credentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let text = String(data: data, encoding: .utf8),
              let split = text.firstIndex(of: "\n") else { return nil }
        return Credentials(email: String(text[..<split]),
                           password: String(text[text.index(after: split)...]))
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
