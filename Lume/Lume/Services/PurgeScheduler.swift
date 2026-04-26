import Foundation

/// Drops non-pinned clips older than each kind's retention window. Runs
/// every 60 minutes and on app launch. Per-kind cutoffs are pulled live
/// from `CaptureSettings` so changing them in the UI takes effect on
/// the next tick.
@MainActor
final class PurgeScheduler {
    private let repository: ClipRepository
    private var timer: Timer?

    init(repository: ClipRepository) { self.repository = repository }

    func start() {
        purgeNow()
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.purgeNow() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func purgeNow() {
        let now = Date()
        let cutoffs: [ClipKind: Date] = [
            .text:  now.addingTimeInterval(TimeInterval(-86_400 * CaptureSettings.retentionText)),
            .rtf:   now.addingTimeInterval(TimeInterval(-86_400 * CaptureSettings.retentionText)),
            .html:  now.addingTimeInterval(TimeInterval(-86_400 * CaptureSettings.retentionText)),
            .code:  now.addingTimeInterval(TimeInterval(-86_400 * CaptureSettings.retentionText)),
            .image: now.addingTimeInterval(TimeInterval(-86_400 * CaptureSettings.retentionImages)),
            .file:  now.addingTimeInterval(TimeInterval(-86_400 * CaptureSettings.retentionFiles)),
            .color: now.addingTimeInterval(TimeInterval(-86_400 * CaptureSettings.retentionColors)),
        ]
        Task.detached(priority: .background) { [repository] in
            do {
                let removed = try repository.purge(perKindCutoffs: cutoffs)
                if removed > 0 { NSLog("[Lume] purged \(removed) clips") }
            } catch {
                NSLog("[Lume] purge failed: \(error)")
            }
        }
    }
}
