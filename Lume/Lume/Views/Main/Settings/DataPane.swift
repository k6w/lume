import SwiftUI
import AppKit
import GRDB

struct DataPane: View {
    let environment: AppEnvironment

    @AppStorage(CaptureSettings.Key.captureImages.rawValue)   private var captureImages: Bool = false
    @AppStorage(CaptureSettings.Key.retentionText.rawValue)   private var retentionText: Int = 30
    @AppStorage(CaptureSettings.Key.retentionImages.rawValue) private var retentionImages: Int = 7
    @AppStorage(CaptureSettings.Key.retentionFiles.rawValue)  private var retentionFiles: Int = 14
    @AppStorage(CaptureSettings.Key.retentionColors.rawValue) private var retentionColors: Int = 90

    @AppStorage(CloudSyncEngine.isEnabledKey) private var iCloudEnabled: Bool = true

    @State private var totalClips: Int = 0

    var body: some View {
        Form {
            Section("What gets captured") {
                LabeledContent("Text & rich text") { Text("Always on").foregroundStyle(.secondary) }
                LabeledContent("Colors")           { Text("Always on").foregroundStyle(.secondary) }
                LabeledContent("File paths")       { Text("Always on").foregroundStyle(.secondary) }
                Toggle("Images", isOn: $captureImages)
                Text("Images store the actual pixel data — usually a few hundred KB per screenshot. Disabled by default to keep the database small.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Auto-purge") {
                Stepper(value: $retentionText, in: 1...365) {
                    Text("Text after **\(retentionText)** days")
                }
                Stepper(value: $retentionColors, in: 1...365) {
                    Text("Colors after **\(retentionColors)** days")
                }
                if captureImages {
                    Stepper(value: $retentionImages, in: 1...90) {
                        Text("Images after **\(retentionImages)** days")
                    }
                }
                Stepper(value: $retentionFiles, in: 1...365) {
                    Text("File paths after **\(retentionFiles)** days")
                }
                Text("Pinned clips are never purged.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Purge now", role: .destructive) { purgeNow() }
            }

            Section("iCloud") {
                Toggle("Sync with iCloud", isOn: $iCloudEnabled)
                    .onChange(of: iCloudEnabled) { _, on in environment.cloud.setEnabled(on) }
                // Read directly from the @Observable engine so this row
                // refreshes the moment a sync pass finishes.
                if let date = environment.cloud.lastSyncedAt {
                    LabeledContent("Last synced", value: date.formatted(.relative(presentation: .numeric)))
                } else {
                    LabeledContent("Last synced", value: "Never")
                }
                LabeledContent("Total clips", value: "\(totalClips)")
                HStack {
                    Button("Sync now") { Task { await environment.cloud.syncOnce(); reload() } }
                    Spacer()
                }
                Text("Clips sync only to your private iCloud database. Lume has no servers and no telemetry.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Export & maintenance") {
                Button("Export history as JSON…") { exportJSON() }
                Button("Compact database (VACUUM)") {
                    Task.detached { try? environment.clipRepository.compact() }
                }
                Button(role: .destructive) {
                    confirmAndClear()
                } label: { Text("Clear all unpinned clips") }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
    }

    private func purgeNow() {
        // Compute the same per-kind cutoffs the scheduler uses, run the
        // purge, and report the row count back to the user. Without this
        // confirmation, "nothing happened" was indistinguishable from
        // "nothing's old enough to purge yet".
        let now = Date()
        let cutoffs: [ClipKind: Date] = [
            .text:  now.addingTimeInterval(TimeInterval(-86_400 * retentionText)),
            .rtf:   now.addingTimeInterval(TimeInterval(-86_400 * retentionText)),
            .html:  now.addingTimeInterval(TimeInterval(-86_400 * retentionText)),
            .code:  now.addingTimeInterval(TimeInterval(-86_400 * retentionText)),
            .image: now.addingTimeInterval(TimeInterval(-86_400 * retentionImages)),
            .file:  now.addingTimeInterval(TimeInterval(-86_400 * retentionFiles)),
            .color: now.addingTimeInterval(TimeInterval(-86_400 * retentionColors)),
        ]
        Task.detached {
            let removed = (try? environment.clipRepository.purge(perKindCutoffs: cutoffs)) ?? 0
            try? environment.clipRepository.compact()
            await MainActor.run {
                let alert = NSAlert()
                if removed == 0 {
                    alert.messageText = "Nothing to purge."
                    alert.informativeText = "No clips are older than the retention windows you set. Pin anything you want to keep forever; everything else falls off automatically."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "Purged \(removed) clip\(removed == 1 ? "" : "s")."
                    alert.informativeText = "Database compacted."
                    alert.alertStyle = .informational
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
                reload()
            }
        }
    }

    private func confirmAndClear() {
        let alert = NSAlert()
        alert.messageText = "Clear all unpinned clips?"
        alert.informativeText = "This deletes every clip that isn't pinned. Pinned clips and snippets are not affected. Cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            Task.detached {
                _ = try? environment.clipRepository.deleteAllUnpinned()
                try? environment.clipRepository.compact()
            }
        }
    }

    private func reload() {
        Task.detached {
            let n = (try? await environment.clipRepository.pool.read { db in
                try Int.fetchOne(db, sql: "SELECT count(*) FROM clip")
            }) ?? 0
            await MainActor.run { totalClips = n }
        }
    }

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "lume-export.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task.detached {
            do {
                let clips = try environment.clipRepository.recent(limit: 100_000)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(clips)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("[Lume] export failed: \(error)")
            }
        }
    }
}
