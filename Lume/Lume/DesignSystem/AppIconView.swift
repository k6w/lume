import SwiftUI
import AppKit

/// Resolves a `bundleIdentifier` to its Finder icon. Falls back to a
/// generic app glyph when the bundle isn't installed (or no longer
/// installed). Resolution is async + cached so list rows stay snappy.
struct AppIconView: View {
    let bundleID: String?
    var size: CGFloat = 16
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
        .task(id: bundleID ?? "") { await resolve() }
    }

    private func resolve() async {
        guard let id = bundleID else { icon = nil; return }
        if let cached = Self.cache[id] { icon = cached; return }
        let resolved: NSImage? = await Task.detached {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        }.value
        if let resolved {
            await MainActor.run {
                Self.cache[id] = resolved
                icon = resolved
            }
        }
    }

    @MainActor private static var cache: [String: NSImage] = [:]
}
