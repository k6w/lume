import Foundation
import CloudKit
import GRDB
import Security

/// Drives the CloudKit private database. One custom zone (`Clips`),
/// change-token-driven delta fetch, batched pushes, and silent-push
/// subscriptions for low-latency wakeups.
///
/// The engine is deliberately conservative: every error path keeps the
/// local store as the source of truth so we never lose user data.
@MainActor
final class CloudSyncEngine {
    static let isEnabledKey = "lume.iCloud.enabled"
    static let containerIdentifier = "iCloud.app.lume.Lume"

    private let database: AppDatabase
    private let repository: ClipRepository
    private let encryption: EncryptionService
    private let queue: SyncQueue

    private var container: CKContainer?
    private var privateDB: CKDatabase?

    private var heartbeat: Timer?
    private var inFlight = false
    private(set) var lastSyncedAt: Date?

    init(database: AppDatabase, repository: ClipRepository, encryption: EncryptionService) {
        self.database = database
        self.repository = repository
        self.encryption = encryption
        self.queue = SyncQueue(database: database)
        // CloudKit container is created lazily in `start()` so the app boots
        // cleanly on builds without the iCloud container entitlement
        // (e.g. local development without an Apple Developer team).
    }

    // MARK: Lifecycle

    func start() async {
        guard isEnabled else { return }
        guard hasICloudEntitlement else {
            NSLog("[Lume] iCloud sync disabled — no iCloud container entitlement.")
            return
        }
        do {
            try resolveContainerIfNeeded()
            try await ensureZoneAndSubscription()
            await syncOnce()
            startHeartbeat()
        } catch {
            NSLog("[Lume] sync start failed: \(error)")
        }
    }

    private func resolveContainerIfNeeded() throws {
        if container != nil { return }
        let c = CKContainer(identifier: Self.containerIdentifier)
        self.container = c
        self.privateDB = c.privateCloudDatabase
    }

    /// Reads the embedded `com.apple.developer.icloud-container-identifiers`
    /// entitlement from the running binary. In a sandboxed build without that
    /// key, we gracefully turn sync off rather than trapping inside CKContainer.
    private var hasICloudEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let key = "com.apple.developer.icloud-container-identifiers" as CFString
        guard let value = SecTaskCopyValueForEntitlement(task, key, nil),
              let array = value as? [String]
        else { return false }
        return array.contains(Self.containerIdentifier)
    }

    func stop() {
        heartbeat?.invalidate()
        heartbeat = nil
    }

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.isEnabledKey) as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.isEnabledKey)
        if enabled {
            Task { await start() }
        } else {
            stop()
        }
    }

    // MARK: One sync pass

    func syncOnce() async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }
        do {
            try await fetchRemoteChanges()
            try await flushPushes()
            try await flushDeletes()
            lastSyncedAt = Date()
        } catch {
            NSLog("[Lume] sync pass failed: \(error)")
        }
    }

    private func startHeartbeat() {
        heartbeat?.invalidate()
        let t = Timer(timeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { await self?.syncOnce() }
        }
        t.tolerance = 30
        RunLoop.main.add(t, forMode: .common)
        heartbeat = t
    }

    // MARK: Zone + subscription

    private func ensureZoneAndSubscription() async throws {
        guard let privateDB else { return }
        let zone = CKRecordZone(zoneID: ClipRecordMapper.zoneID)
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
        let subID = "lume-clips-sub"
        let subscription = CKDatabaseSubscription(subscriptionID: subID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        _ = try? await privateDB.modifySubscriptions(saving: [subscription], deleting: [])
    }

    // MARK: Fetch

    private func fetchRemoteChanges() async throws {
        guard let privateDB else { return }
        let token = try queue.loadChangeToken().flatMap { data -> CKServerChangeToken? in
            try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self, from: data
            )
        }

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?

        let result = try await privateDB.recordZoneChanges(
            inZoneWith: ClipRecordMapper.zoneID,
            since: token
        )

        for change in result.modificationResultsByID {
            if case .success(let modification) = change.value {
                changedRecords.append(modification.record)
            }
        }
        for change in result.deletions {
            deletedRecordIDs.append(change.recordID)
        }
        newToken = result.changeToken

        for record in changedRecords {
            applyRemote(record)
        }
        for id in deletedRecordIDs {
            try? repository.delete(id: id.recordName)
        }

        if let newToken {
            let data = try NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
            try queue.saveChangeToken(data)
        }
    }

    private func applyRemote(_ record: CKRecord) {
        guard let remote = ClipRecordMapper.makeClip(from: record) else { return }
        do {
            if let local = try repository.clip(id: remote.id) {
                let merged = ConflictResolver.merge(local: local, remote: remote)
                try repository.upsert(merged)
            } else {
                try repository.upsert(remote)
            }
        } catch {
            NSLog("[Lume] applyRemote failed: \(error)")
        }
    }

    // MARK: Push

    private func flushPushes() async throws {
        guard let privateDB else { return }
        let ids = try queue.pendingPushes()
        guard !ids.isEmpty else { return }

        var records: [CKRecord] = []
        var nameByID: [String: String] = [:]

        for id in ids {
            guard let clip = try repository.clip(id: id) else { continue }
            let record = try ClipRecordMapper.makeRecord(from: clip)
            records.append(record)
            nameByID[id] = record.recordID.recordName
        }
        guard !records.isEmpty else { return }

        let saveResult = try await privateDB.modifyRecords(
            saving: records, deleting: [], savePolicy: .changedKeys, atomically: false
        )

        var changeTagByID: [String: String] = [:]
        for (recordID, modificationResult) in saveResult.saveResults {
            if case .success(let saved) = modificationResult {
                changeTagByID[recordID.recordName] = saved.recordChangeTag
            }
        }

        try queue.markSynced(clipIDs: ids, recordNames: nameByID, changeTags: changeTagByID)
    }

    private func flushDeletes() async throws {
        guard let privateDB else { return }
        let ids = try queue.pendingDeletes()
        guard !ids.isEmpty else { return }
        let recordIDs = ids.map { CKRecord.ID(recordName: $0, zoneID: ClipRecordMapper.zoneID) }
        _ = try? await privateDB.modifyRecords(
            saving: [], deleting: recordIDs, savePolicy: .changedKeys, atomically: false
        )
        try queue.clearTombstones(clipIDs: ids)
    }
}
