import SwiftUI

struct TagsStep: View {
    @LumeAccent private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            OnboardingHeader(
                eyebrow: "03 · Tags",
                title: "Bucket your clips.",
                lede: "Color-coded tags with custom icons. Apply from the detail pane. Filter from the toolbar."
            )
            OnboardingCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        tagPreview(name: "Work",   icon: "briefcase",       color: .blue)
                        tagPreview(name: "Code",   icon: "curlybraces",     color: .purple)
                        tagPreview(name: "Receipts", icon: "doc.text",      color: .green)
                        tagPreview(name: "Ideas",  icon: "lightbulb",       color: .orange)
                    }
                    Divider().opacity(0.25)
                    Text("Manage tags in Settings → Tags. Each one has a name, a color, and an SF Symbol picked from a curated grid.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.s)
    }

    private func tagPreview(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(name).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.5))
    }
}
