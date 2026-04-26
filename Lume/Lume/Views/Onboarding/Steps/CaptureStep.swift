import SwiftUI

struct CaptureStep: View {
    @LumeAccent private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            OnboardingHeader(
                eyebrow: "01 · Capture",
                title: "Everything you copy.",
                lede: "Lume watches the pasteboard and keeps a private, local history. Text, colors, file paths — captured automatically."
            )
            OnboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    captureRow(symbol: "text.alignleft",        title: "Text · RTF · HTML",  detail: "Always on. Plain + formatted ride together.")
                    captureRow(symbol: "paintpalette",          title: "Colors",              detail: "Hex codes and color-picker drops auto-detect.")
                    captureRow(symbol: "doc",                   title: "File paths",          detail: "Always on — only the path string, no file body.")
                    captureRow(symbol: "photo",                 title: "Images",              detail: "Opt-in in Settings → Data. Disabled by default.")
                }
            }
            Text("Want any of this off in a specific app? Settings → Privacy → Excluded apps lets you blocklist by bundle ID.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Tokens.Spacing.s)
    }

    private func captureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(accent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
