import SwiftUI

struct FindStep: View {
    @LumeAccent private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            OnboardingHeader(
                eyebrow: "02 · Find",
                title: "It's all searchable.",
                lede: "FTS5 full-text search runs in a single frame even with 100k clips. Smart filters help you slice the haystack."
            )
            OnboardingCard {
                VStack(alignment: .leading, spacing: 14) {
                    sampleSearch
                    Divider().opacity(0.25)
                    HStack(spacing: 8) {
                        filterChip("All Clips", "tray.full")
                        filterChip("Pinned", "pin.fill")
                        filterChip("URLs", "link")
                        filterChip("Today", "sun.max")
                        filterChip("Files", "doc")
                    }
                }
            }
            Text("Sidebar filters are computed on the fly via NSDataDetector — no tagging, no setup.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Tokens.Spacing.s)
    }

    private var sampleSearch: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text("invoice 2026")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
            Text("3 matches in <16ms")
                .font(.caption.monospacedDigit())
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func filterChip(_ label: String, _ symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption)
            Text(label).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(accent.opacity(0.16),
                    in: Capsule(style: .continuous))
        .foregroundStyle(accent)
    }
}
