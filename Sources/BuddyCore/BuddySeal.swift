import Foundation
import CryptoKit

/// Basic AES-GCM encryption for data at rest. Key lives in the Keychain.
public enum BuddySeal {
    public enum SealError: Error {
        case keychain(BuddyKeychain.KeychainError)
        case sealFailed
        case openFailed
    }

    private static let service = "com.buddy.storage.aes-gcm"
    private static let account = "master-v1"

    /// 256-bit AES key, created once and stored in Keychain (This Device Only).
    public static func masterKey() throws -> SymmetricKey {
        do {
            let existing = try BuddyKeychain.getData(account: account, service: service)
            return SymmetricKey(data: existing)
        } catch BuddyKeychain.KeychainError.noData {
            let key = SymmetricKey(size: .bits256)
            let raw = key.withUnsafeBytes { Data($0) }
            do {
                try BuddyKeychain.setData(raw, account: account, service: service)
            } catch let error as BuddyKeychain.KeychainError {
                throw SealError.keychain(error)
            }
            return key
        } catch let error as BuddyKeychain.KeychainError {
            throw SealError.keychain(error)
        }
    }

    public static func seal(_ plaintext: Data) throws -> Data {
        let key = try masterKey()
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else { throw SealError.sealFailed }
        return combined
    }

    public static func open(_ sealed: Data) throws -> Data {
        let key = try masterKey()
        let box = try AES.GCM.SealedBox(combined: sealed)
        do {
            return try AES.GCM.open(box, using: key)
        } catch {
            throw SealError.openFailed
        }
    }

    public static func sealJSON<T: Encodable>(_ value: T) throws -> Data {
        let data = try JSONEncoder().encode(value)
        return try seal(data)
    }

    public static func openJSON<T: Decodable>(_ sealed: Data, as type: T.Type) throws -> T {
        let data = try open(sealed)
        return try JSONDecoder().decode(type, from: data)
    }
}
