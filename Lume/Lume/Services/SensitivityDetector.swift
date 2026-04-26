import Foundation

/// Heuristics for "this clip looks like a secret".
///
/// Two signals:
///  1. Source app — known password managers always count as sensitive.
///  2. Shape + entropy — a no-whitespace 12–64 char string with Shannon
///     entropy ≥ 4.5 bits/char is almost certainly a generated secret.
final class SensitivityDetector: @unchecked Sendable {
    private let knownVaults: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx-helper",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "com.apple.keychainaccess"
    ]

    func isLikelySensitive(_ clip: Clip) -> Bool {
        if let bid = clip.sourceBundleID, knownVaults.contains(bid) { return true }
        guard clip.kind == .text, let s = clip.plainText else { return false }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (12...64).contains(trimmed.count),
              !trimmed.contains(where: { $0.isWhitespace })
        else { return false }
        // Practical floor: log2(16) = 4.0 — a 16-char string with all
        // distinct chars sits exactly at this line. Generated secrets
        // are usually well above; prose is well below.
        return Self.shannonEntropy(of: trimmed) >= 4.0
    }

    static func shannonEntropy(of s: String) -> Double {
        guard !s.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for ch in s { counts[ch, default: 0] += 1 }
        let n = Double(s.count)
        var h = 0.0
        for (_, c) in counts {
            let p = Double(c) / n
            h -= p * (log(p) / log(2.0))
        }
        return h
    }
}
