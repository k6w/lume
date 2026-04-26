import Foundation
import GRDB

/// A single clipboard entry.
///
/// Identity is `id` (UUID). Dedup is `contentHash` (SHA-256 of the
/// normalized payload) — we keep both because CloudKit needs the UUID
/// to be stable across devices, but dedup is by content.
struct Clip: Identifiable, Codable, Hashable, Sendable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clip"

    var id: String                   // UUID string
    var contentHash: String          // SHA-256 hex
    var kind: ClipKind
    var plainText: String?
    var rtfData: Data?
    var htmlData: Data?
    var imageData: Data?
    /// 200×200 JPEG pre-thumbnailed at insert time. Cheap to decode in lists.
    var thumbnailData: Data?
    var fileURLs: String?            // JSON array of bookmark/strings
    var colorHex: String?
    var detectedLanguage: String?
    var sourceBundleID: String?
    var byteSize: Int
    var isPinned: Bool
    var isEncrypted: Bool
    var encryptedBlob: Data?
    var createdAt: Date
    var lastSeenAt: Date
    var hitCount: Int

    enum Columns: String, ColumnExpression {
        case id, contentHash, kind, plainText, rtfData, htmlData, imageData, thumbnailData
        case fileURLs, colorHex, detectedLanguage, sourceBundleID, byteSize
        case isPinned, isEncrypted, encryptedBlob
        case createdAt, lastSeenAt, hitCount
    }

    /// Convenience constructor for a freshly captured text clip.
    static func text(
        _ string: String,
        sourceBundleID: String?,
        thumbnailData: Data? = nil
    ) -> Clip {
        let now = Date()
        return Clip(
            id: UUID().uuidString,
            contentHash: ContentHasher.hash(kind: .text, payload: Data(string.utf8)),
            kind: .text,
            plainText: string,
            rtfData: nil,
            htmlData: nil,
            imageData: nil,
            thumbnailData: thumbnailData,
            fileURLs: nil,
            colorHex: nil,
            detectedLanguage: nil,
            sourceBundleID: sourceBundleID,
            byteSize: string.utf8.count,
            isPinned: false,
            isEncrypted: false,
            encryptedBlob: nil,
            createdAt: now,
            lastSeenAt: now,
            hitCount: 1
        )
    }
}

extension Clip {
    /// A short, human-friendly preview, lazily computed.
    var preview: String {
        if let plainText { return plainText.singleLine().prefix(160).description }
        switch kind {
        case .image: return "Image"
        case .file:  return fileURLs ?? "File"
        case .color: return colorHex ?? "Color"
        default:     return kind.displayName
        }
    }

    /// File URLs split out of the newline-joined `fileURLs` field.
    var fileURLArray: [URL] {
        guard kind == .file, let raw = fileURLs else { return [] }
        return raw.split(separator: "\n")
                  .map { URL(fileURLWithPath: String($0)) }
    }

    /// True only if every captured path is still on disk. False if any is
    /// missing, so the UI can show a "moved or deleted" badge.
    var allFilesExist: Bool {
        let urls = fileURLArray
        guard !urls.isEmpty else { return true }
        return urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }
}

private extension String {
    func singleLine() -> String {
        replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
