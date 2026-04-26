import SwiftUI

struct SnippetsStep: View {
    @LumeAccent private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            OnboardingHeader(
                eyebrow: "04 · Snippets",
                title: "Boilerplate, with variables.",
                lede: "Save reusable text — signatures, code blocks, replies. Drop variables for the date, time, or current clipboard."
            )
            OnboardingCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "text.append")
                            .foregroundStyle(accent)
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6).fill(accent.opacity(0.16)))
                        Text("Email signature")
                            .font(.headline)
                        Spacer()
                    }
                    Text("""
                    Best,
                    {{name}} · sent {{date}}
                    """)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    HStack(spacing: 6) {
                        variable("date")
                        variable("time")
                        variable("datetime")
                        variable("clipboard")
                    }
                }
            }
            Text("Find your snippets in the popover footer (Snippets menu) or in the Snippets sidebar tab.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Tokens.Spacing.s)
    }

    private func variable(_ name: String) -> some View {
        Text("{{\(name)}}")
            .font(.caption.monospaced())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(accent.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .foregroundStyle(accent)
    }
}
