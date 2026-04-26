import SwiftUI

struct PrivacyPane: View {
    let environment: AppEnvironment
    @State private var excludedApps: [String] = []
    @State private var newBundleID: String = ""
    @AppStorage("lume.encryptSensitive") private var encryptSensitive: Bool = true

    var body: some View {
        Form {
            Section("Excluded apps") {
                Text("Lume will not record anything copied while these apps are frontmost.")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(excludedApps, id: \.self) { bid in
                    HStack {
                        Text(bid).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button { remove(bid) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("com.example.app", text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") { add() }
                }
            }
            Section("Sensitive content") {
                Toggle("Encrypt clips that look like secrets", isOn: $encryptSensitive)
                Text("Heuristic: source app is a known password manager, or the clip looks like a generated secret. Encrypted clips sync to iCloud as ciphertext only; the key never leaves your iCloud Keychain.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
    }

    private func reload() {
        Task.detached {
            let pool = environment.clipRepository.pool
            let list = (try? await pool.read { db in
                try String.fetchAll(db, sql: "SELECT bundleID FROM excluded_app ORDER BY bundleID")
            }) ?? []
            await MainActor.run {
                excludedApps = list
                PasteboardWatcher.excludedAppCache = Set(list)
            }
        }
    }

    private func add() {
        let trimmed = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task.detached {
            try? await environment.clipRepository.pool.write { db in
                try db.execute(sql: """
                    INSERT OR IGNORE INTO excluded_app(bundleID, addedAt) VALUES (?, ?)
                """, arguments: [trimmed, Date()])
            }
            await MainActor.run { newBundleID = "" }
            await MainActor.run { reload() }
        }
    }

    private func remove(_ bid: String) {
        Task.detached {
            try? await environment.clipRepository.pool.write { db in
                try db.execute(sql: "DELETE FROM excluded_app WHERE bundleID = ?", arguments: [bid])
            }
            await MainActor.run { reload() }
        }
    }
}
