import Foundation
import CryptoKit

/// SHA-256 hex digest of a normalized blob (`kind || payload`).
/// Used as the unique key for clip dedup, both locally and across devices.
enum ContentHasher {
    static func hash(kind: ClipKind, payload: Data) -> String {
        var hasher = SHA256()
        var k = UInt8(kind.rawValue)
        withUnsafeBytes(of: &k) { hasher.update(bufferPointer: $0) }
        hasher.update(data: payload)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
