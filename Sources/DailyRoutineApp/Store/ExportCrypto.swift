import Foundation
import CryptoKit

/// Lightweight obfuscation for exported backup files.
///
/// IMPORTANT: the key is derived from a constant compiled into the app, so this
/// is **obfuscation, not real security** — it stops a casual person from reading
/// a backup in a text editor, but anyone who inspects the binary can recover the
/// key and decrypt any file. This is a deliberate choice for a low-sensitivity
/// to-do app: it avoids the data-loss risk of a user-chosen passphrase (forgotten
/// password = lost backup) while keeping exports non-human-readable.
enum ExportCrypto {

    enum CryptoError: Error { case sealFailed }

    /// 6-byte marker prefixed to every encrypted container, so `importData` can
    /// distinguish an encrypted backup from a plain-JSON one (which starts `{`).
    private static let magic = Data("DRBK01".utf8)

    /// App-embedded secret → SHA-256 → 256-bit symmetric key.
    private static var key: SymmetricKey {
        let secret = "DailyRoutine.export.v1::whisk-amber-ledger-0913"
        let digest = SHA256.hash(data: Data(secret.utf8))
        return SymmetricKey(data: Data(digest))
    }

    /// Encrypts `plaintext` with AES-GCM and returns `magic + (nonce|ciphertext|tag)`.
    static func encrypt(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.sealFailed }
        return magic + combined
    }

    /// If `data` is one of our encrypted containers, returns the decrypted
    /// plaintext. Returns `nil` when `data` isn't encrypted (caller falls back to
    /// plain JSON). Throws if it *looks* encrypted but can't be opened.
    static func decryptIfEncrypted(_ data: Data) throws -> Data? {
        guard data.starts(with: magic) else { return nil }
        let body = data.subdata(in: magic.count ..< data.count)
        let box = try AES.GCM.SealedBox(combined: body)
        return try AES.GCM.open(box, using: key)
    }
}
