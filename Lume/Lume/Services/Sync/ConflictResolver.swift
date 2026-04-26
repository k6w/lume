import Foundation

/// Reconciles a remote `Clip` arriving from CloudKit with whatever the
/// local store currently has. We never lose pins or hit-counts:
///
///  - `lastSeenAt`: max of both
///  - `hitCount`:   max of both (cheaper than tracking deltas)
///  - `isPinned`:   logical OR
///  - everything else: the side with the newer `lastSeenAt` wins
enum ConflictResolver {
    static func merge(local: Clip, remote: Clip) -> Clip {
        let localIsNewer = local.lastSeenAt >= remote.lastSeenAt
        var winner = localIsNewer ? local : remote
        winner.lastSeenAt = max(local.lastSeenAt, remote.lastSeenAt)
        winner.hitCount   = max(local.hitCount,   remote.hitCount)
        winner.isPinned   = local.isPinned || remote.isPinned
        return winner
    }
}
