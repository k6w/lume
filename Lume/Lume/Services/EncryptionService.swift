import Foundation
import CryptoKit
import Security

/// Encrypts sensitive clips with ChaCha20-Poly1305. The symmetric key
/// lives in the Keychain with `kSecAttrSynchronizable=true`, so iCloud
/// Keychain ferries it between devices. Ciphertext can therefore go
/// through CloudKit safely without ever exposing plaintext.
final class EncryptionService: @unchecked Sendable {
    private let keyTag = "app.lume.Lume.clipKey"
    private let lock = NSLock()
    private var cachedKey: SymmetricKey?

    /// Returns the (cached) symmetric key, creating one on first use.
    private func key() -> SymmetricKey {
        lock.lock(); defer { lock.unlock() }
        if let cached = cachedKey { return cached }
        if let stored = readKey() {
            cachedKey = stored
            return stored
        }
        let fresh = SymmetricKey(size: .bits256)
        writeKey(fresh)
        cachedKey = fresh
        return fresh
    }

    /// Replace plaintext fields with sealed ciphertext.
    func seal(_ clip: Clip) -> Clip {
        guard let plain = clip.plainText, let plainData = plain.data(using: .utf8) else {
            return clip
        }
        do {
            let sealed = try ChaChaPoly.seal(plainData, using: key()).combined
            var c = clip
            c.isEncrypted = true
            c.encryptedBlob = sealed
            c.plainText = nil
            c.rtfData = nil
            c.htmlData = nil
            return c
        } catch {
            NSLog("[Lume] seal failed: \(error)")
            return clip
        }
    }

    /// Open a sealed clip back into plaintext. Returns the original clip
    /// untouched if it isn't encrypted or if opening fails.
    func open(_ clip: Clip) -> Clip {
        guard clip.isEncrypted, let blob = clip.encryptedBlob else { return clip }
        do {
            let box = try ChaChaPoly.SealedBox(combined: blob)
            let opened = try ChaChaPoly.open(box, using: key())
            var c = clip
            c.plainText = String(data: opened, encoding: .utf8)
            return c
        } catch {
            NSLog("[Lume] open failed: \(error)")
            return clip
        }
    }

    // MARK: Keychain

    private func readKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      keyTag,
            kSecAttrAccount as String:      keyTag,
            kSecReturnData  as String:      true,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private func writeKey(_ key: SymmetricKey) {
        let data = key.withUnsafeBytes { Data($0) }
        let attrs: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      keyTag,
            kSecAttrAccount as String:      keyTag,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]
        SecItemDelete(attrs as CFDictionary)
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("[Lume] key write failed: \(status)")
        }
    }
}
