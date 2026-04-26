import SwiftUI

/// Curated SF Symbol picker. ~80 icons grouped by theme so users can pick
/// one for a tag without scrolling forever. The list intentionally trades
/// breadth for relevance — the symbols here are the ones people actually
/// reach for when bucketing clips (work / code / comm / time / misc).
struct SFSymbolPicker: View {
    @Environment(LumeTheme.self) private var theme
    @Binding var selection: String
    /// Accent override; nil falls back to the env theme accent so callers
    /// don't need to pass anything in the common case.
    var tint: Color? = nil
    private var effectiveTint: Color { tint ?? theme.accent }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Self.choices, id: \.self) { name in
                    cell(name)
                }
            }
            .padding(2)
        }
        .frame(minHeight: 220, idealHeight: 280)
    }

    private func cell(_ name: String) -> some View {
        let isSelected = name == selection
        return Button {
            selection = name
        } label: {
            Image(systemName: name)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(isSelected ? Color.white : effectiveTint)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? effectiveTint : effectiveTint.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .help(name)
    }

    static let choices: [String] = [
        // Tags / staples
        "tag", "tag.fill", "star", "star.fill", "heart", "heart.fill",
        "flag", "flag.fill", "bookmark", "bookmark.fill",
        "pin", "pin.fill", "checkmark.circle", "exclamationmark.triangle",
        "lightbulb", "sparkles",

        // Work
        "briefcase", "doc", "doc.text", "folder", "folder.fill",
        "tray", "tray.full", "archivebox",

        // People
        "person", "person.fill", "person.2", "person.3", "building.2",

        // Code
        "curlybraces", "chevron.left.forwardslash.chevron.right",
        "terminal", "function", "swift", "hammer", "wrench.and.screwdriver",

        // Communication
        "envelope", "envelope.fill", "message", "bubble.left",
        "phone", "video", "mic",

        // Web / network
        "globe", "link", "network", "wifi", "icloud",

        // Money / commerce
        "dollarsign.circle", "creditcard", "banknote", "cart",

        // Travel / location
        "airplane", "car", "bicycle", "location", "map",

        // Time
        "clock", "calendar", "hourglass", "timer", "alarm",

        // Tools / craft
        "gearshape", "wrench", "scissors", "paintbrush", "pencil",
        "ruler", "magnifyingglass",

        // Media
        "photo", "music.note", "film", "headphones", "play.rectangle",

        // Security
        "lock", "lock.open", "shield", "key",

        // Mood / nature
        "leaf", "flame", "drop", "snowflake", "sun.max", "moon",
        "gift", "trophy", "balloon"
    ]
}
