import Foundation
import Security

/// Secure storage helper using system Keychain for passwords, with memory cache fallback.
public final class KeychainStore: @unchecked Sendable {
    public static let shared = KeychainStore()

    private let serviceName = "com.tailscreens.credentials"
    private var inMemoryStore: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    /// Save a password for a given device ID or key.
    @discardableResult
    public func savePassword(_ password: String, forKey key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        inMemoryStore[key] = password

        guard let data = password.data(using: .utf8) else { return false }

        // Remove existing item if present
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve a saved password for a given device ID or key.
    public func loadPassword(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = inMemoryStore[key] {
            return cached
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return inMemoryStore[key]
        }

        inMemoryStore[key] = password
        return password
    }

    /// Delete a saved password.
    @discardableResult
    public func deletePassword(forKey key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        inMemoryStore.removeValue(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
