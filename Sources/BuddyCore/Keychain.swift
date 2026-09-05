import Foundation
import Security

public enum BuddyKeychain {
    public enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case noData
    }

    public static func set(_ value: String, account: String, service: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    public static func get(account: String, service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.noData
        }
        return value
    }

    public static func delete(account: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Holds OTPs briefly in memory only.
public final class EphemeralOTPCache: @unchecked Sendable {
    private let lock = NSLock()
    private var value: (code: String, expiry: Date)?

    public init() {}

    public func store(_ code: String, ttl: TimeInterval = 60) {
        lock.lock()
        defer { lock.unlock() }
        value = (code, Date().addingTimeInterval(ttl))
    }

    public func current() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let value else { return nil }
        if value.expiry < Date() {
            self.value = nil
            return nil
        }
        return value.code
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        value = nil
    }
}
