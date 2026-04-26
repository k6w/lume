import SwiftUI

struct PermissionsStep: View {
    @Environment(LumeTheme.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            Spacer(minLength: 0)
            Text("What Lume can see")
                .font(.system(size: 28, weight: .semibold))
            row(symbol: "doc.on.clipboard",
                title: "Clipboard contents",
                body: "Lume reads NSPasteboard whenever it changes. No permission required.")
            row(symbol: "icloud",
                title: "iCloud (your private database)",
                body: "Backups and cross-Mac sync go through your own iCloud container. Lume has no servers.")
            row(symbol: "lock.shield",
                title: "Sensitive content",
                body: "Clips that look like passwords are encrypted with ChaCha20-Poly1305 before they ever touch the disk or iCloud.")
            row(symbol: "keyboard",
                title: "Optional: Accessibility",
                body: "Grant later if you want Lume to press ⌘V for you. Without it, paste is a manual ⌘V — Lume still puts the clip on your pasteboard.")
            Spacer(minLength: 0)
        }
    }

    private func row(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(theme.accent)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(theme.accent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).foregroundStyle(.secondary).font(.subheadline)
            }
        }
    }
}
