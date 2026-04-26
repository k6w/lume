import Foundation
import CloudKit

/// Bidirectional mapping between `Clip` and `CKRecord`. Large payloads
/// (image, file bundle) ship as `CKAsset`. Encrypted clips ship only
/// their ciphertext; their plaintext fields are nil.
enum ClipRecordMapper {
    static let recordType = "Clip"
    static let zoneID = CKRecordZone.ID(zoneName: "Clips", ownerName: CKCurrentUserDefaultName)

    static func makeRecord(from clip: Clip, existingName: String? = nil) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: existingName ?? clip.id, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["contentHash"]      = clip.contentHash as CKRecordValue
        record["kind"]             = clip.kind.rawValue as CKRecordValue
        record["sourceBundleID"]   = clip.sourceBundleID as CKRecordValue?
        record["colorHex"]         = clip.colorHex as CKRecordValue?
        record["detectedLanguage"] = clip.detectedLanguage as CKRecordValue?
        record["fileURLs"]         = clip.fileURLs as CKRecordValue?
        record["byteSize"]         = clip.byteSize as CKRecordValue
        record["isPinned"]         = (clip.isPinned ? 1 : 0) as CKRecordValue
        record["isEncrypted"]      = (clip.isEncrypted ? 1 : 0) as CKRecordValue
        record["createdAt"]        = clip.createdAt as CKRecordValue
        record["lastSeenAt"]       = clip.lastSeenAt as CKRecordValue
        record["hitCount"]         = clip.hitCount as CKRecordValue

        // Plaintext stays inline (small, easy to query).
        if !clip.isEncrypted, let s = clip.plainText {
            record["plainText"] = s as CKRecordValue
        }

        // Heavy payloads go through assets so we don't blow the CKRecord size cap.
        if let blob = clip.encryptedBlob {
            record["encryptedAsset"] = try makeAsset(from: blob, name: "encrypted")
        }
        if let img = clip.imageData {
            record["imageAsset"] = try makeAsset(from: img, name: "image")
        }
        if let thumb = clip.thumbnailData {
            record["thumbnailAsset"] = try makeAsset(from: thumb, name: "thumbnail")
        }
        if let rtf = clip.rtfData {
            record["rtfAsset"] = try makeAsset(from: rtf, name: "rtf")
        }
        if let html = clip.htmlData {
            record["htmlAsset"] = try makeAsset(from: html, name: "html")
        }
        return record
    }

    static func makeClip(from record: CKRecord) -> Clip? {
        guard let hash = record["contentHash"] as? String,
              let kindRaw = record["kind"] as? Int,
              let kind = ClipKind(rawValue: kindRaw),
              let createdAt  = record["createdAt"]  as? Date,
              let lastSeenAt = record["lastSeenAt"] as? Date,
              let hitCount   = record["hitCount"]   as? Int,
              let byteSize   = record["byteSize"]   as? Int
        else { return nil }

        return Clip(
            id: record.recordID.recordName,
            contentHash: hash,
            kind: kind,
            plainText: record["plainText"] as? String,
            rtfData:    readAsset(record["rtfAsset"]  as? CKAsset),
            htmlData:   readAsset(record["htmlAsset"] as? CKAsset),
            imageData:  readAsset(record["imageAsset"] as? CKAsset),
            thumbnailData: readAsset(record["thumbnailAsset"] as? CKAsset),
            fileURLs: record["fileURLs"] as? String,
            colorHex: record["colorHex"] as? String,
            detectedLanguage: record["detectedLanguage"] as? String,
            sourceBundleID: record["sourceBundleID"] as? String,
            byteSize: byteSize,
            isPinned: (record["isPinned"] as? Int ?? 0) != 0,
            isEncrypted: (record["isEncrypted"] as? Int ?? 0) != 0,
            encryptedBlob: readAsset(record["encryptedAsset"] as? CKAsset),
            createdAt: createdAt,
            lastSeenAt: lastSeenAt,
            hitCount: hitCount
        )
    }

    private static func makeAsset(from data: Data, name: String) throws -> CKAsset {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lume-asset-\(name)-\(UUID().uuidString)")
        try data.write(to: url, options: .atomic)
        return CKAsset(fileURL: url)
    }

    private static func readAsset(_ asset: CKAsset?) -> Data? {
        guard let url = asset?.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }
}
