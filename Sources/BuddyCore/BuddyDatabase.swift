import Foundation
import SQLite3

/// Simple SQLite store. Payloads are AES-GCM sealed blobs (see `BuddySeal`).
public final class BuddyDatabase: @unchecked Sendable {
    public enum StoreKey: String {
        case clipboardItems = "clipboard.items"
        case clipboardFavorites = "clipboard.favorites"
        case screenshots = "screenshots.items"
    }

    public enum DatabaseError: Error {
        case openFailed
        case prepareFailed
        case stepFailed
        case notFound
    }

    private let db: OpaquePointer?
    private let lock = NSLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(appFolderName: String) throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = root.appendingPathComponent(appFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("buddy.sqlite")

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            throw DatabaseError.openFailed
        }
        db = handle
        try exec("""
            CREATE TABLE IF NOT EXISTS sealed_kv (
              key TEXT PRIMARY KEY NOT NULL,
              ciphertext BLOB NOT NULL,
              updated_at REAL NOT NULL
            );
            """)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public func saveSealedJSON<T: Encodable>(_ value: T, for key: StoreKey) throws {
        let ciphertext = try BuddySeal.sealJSON(value)
        try upsert(key: key.rawValue, ciphertext: ciphertext)
    }

    public func loadSealedJSON<T: Decodable>(_ type: T.Type, for key: StoreKey) throws -> T {
        let ciphertext = try loadCiphertext(key: key.rawValue)
        return try BuddySeal.openJSON(ciphertext, as: type)
    }

    public func loadSealedJSONIfPresent<T: Decodable>(_ type: T.Type, for key: StoreKey) -> T? {
        (try? loadSealedJSON(type, for: key))
    }

    private func upsert(key: String, ciphertext: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        let sql = """
        INSERT INTO sealed_kv(key, ciphertext, updated_at) VALUES(?,?,?)
        ON CONFLICT(key) DO UPDATE SET ciphertext=excluded.ciphertext, updated_at=excluded.updated_at;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DatabaseError.prepareFailed }
        defer { sqlite3_finalize(stmt) }
        _ = key.withCString { sqlite3_bind_text(stmt, 1, $0, -1, transient) }
        ciphertext.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 2, raw.baseAddress, Int32(ciphertext.count), transient)
        }
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw DatabaseError.stepFailed }
    }

    private func loadCiphertext(key: String) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT ciphertext FROM sealed_kv WHERE key=? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DatabaseError.prepareFailed }
        defer { sqlite3_finalize(stmt) }
        _ = key.withCString { sqlite3_bind_text(stmt, 1, $0, -1, transient) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw DatabaseError.notFound }
        guard let bytes = sqlite3_column_blob(stmt, 0) else { throw DatabaseError.notFound }
        let count = Int(sqlite3_column_bytes(stmt, 0))
        return Data(bytes: bytes, count: count)
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &err)
        if let err {
            sqlite3_free(err)
        }
        guard status == SQLITE_OK else { throw DatabaseError.prepareFailed }
    }
}
