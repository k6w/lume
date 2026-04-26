import SwiftUI
import AppKit

/// Shown above MainWindowRoot's content when a newer release is on
/// GitHub. Single accent strip — clickable, dismissible per-version.
struct UpdateBanner: View {
    @Environment(LumeTheme.self) private var theme
    let release: UpdateChecker.ReleaseInfo
    var installedVersion: String
    var onOpen: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.accent)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("Lume \(release.tag) is available")
                    .font(.subheadline.weight(.semibold))
                Text("Installed v\(installedVersion). Click to view release notes and download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("View") {
                NSWorkspace.shared.open(release.url)
                onOpen()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Don't tell me about this version again")
        }
        .padding(.horizontal, Tokens.Spacing.l)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.separator).frame(height: 1)
        }
    }
}
