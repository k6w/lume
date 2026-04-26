import Foundation

/// Native NSDataDetector-driven text introspection. Used by the smart
/// filters in the sidebar (URLs, Emails) and by the detail pane to surface
/// "Open URL" / "Send Email" actions.
enum TextDetector {
    private static let linkDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()
    private static let phoneDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
    }()
    /// Email regex, conservative. We rely on this rather than NSDataDetector
    /// because NSDataDetector classes emails as `.link` (mailto:) and we
    /// want a separate signal.
    private static let emailRegex = #"[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#

    static func containsURL(_ s: String) -> Bool { firstURL(in: s) != nil }
    static func containsEmail(_ s: String) -> Bool { firstEmail(in: s) != nil }
    static func containsPhone(_ s: String) -> Bool {
        guard let d = phoneDetector else { return false }
        return d.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    static func firstURL(in s: String) -> URL? {
        guard let d = linkDetector else { return nil }
        let range = NSRange(s.startIndex..., in: s)
        guard let match = d.firstMatch(in: s, range: range), let url = match.url else { return nil }
        // Skip mailto: — those are emails, not URLs.
        if url.scheme == "mailto" { return nil }
        return url
    }

    static func firstEmail(in s: String) -> String? {
        guard let r = s.range(of: emailRegex, options: .regularExpression) else { return nil }
        return String(s[r])
    }

    static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    static func lineCount(_ s: String) -> Int {
        max(1, s.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    /// Format transformations the detail pane exposes as quick actions.
    enum Transform {
        case lowercase, uppercase, trim
        case prettyJSON, base64Encode, base64Decode
        case urlEncode, urlDecode

        var label: String {
            switch self {
            case .lowercase:    return "Lowercase"
            case .uppercase:    return "Uppercase"
            case .trim:         return "Trim Whitespace"
            case .prettyJSON:   return "JSON Pretty Print"
            case .base64Encode: return "Base64 Encode"
            case .base64Decode: return "Base64 Decode"
            case .urlEncode:    return "URL Encode"
            case .urlDecode:    return "URL Decode"
            }
        }
        var symbol: String {
            switch self {
            case .lowercase:    return "textformat.size.smaller"
            case .uppercase:    return "textformat.size.larger"
            case .trim:         return "scissors"
            case .prettyJSON:   return "curlybraces"
            case .base64Encode: return "arrow.up.square"
            case .base64Decode: return "arrow.down.square"
            case .urlEncode:    return "link"
            case .urlDecode:    return "link.circle"
            }
        }

        /// Apply, returning nil when the input doesn't fit (e.g. invalid JSON).
        func apply(to s: String) -> String? {
            switch self {
            case .lowercase: return s.lowercased()
            case .uppercase: return s.uppercased()
            case .trim:      return s.trimmingCharacters(in: .whitespacesAndNewlines)
            case .prettyJSON:
                guard let data = s.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data),
                      let pretty = try? JSONSerialization.data(withJSONObject: obj,
                          options: [.prettyPrinted, .sortedKeys]),
                      let str = String(data: pretty, encoding: .utf8)
                else { return nil }
                return str
            case .base64Encode:
                return Data(s.utf8).base64EncodedString()
            case .base64Decode:
                guard let data = Data(base64Encoded: s.trimmingCharacters(in: .whitespacesAndNewlines)),
                      let str = String(data: data, encoding: .utf8)
                else { return nil }
                return str
            case .urlEncode:
                return s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            case .urlDecode:
                return s.removingPercentEncoding
            }
        }

        /// True when applying this transform to `s` is meaningful — used to
        /// hide actions that don't make sense for the current clip.
        func applies(to s: String) -> Bool {
            switch self {
            case .lowercase, .uppercase, .trim, .urlEncode, .base64Encode:
                return !s.isEmpty
            case .prettyJSON:
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.hasPrefix("{") || t.hasPrefix("[")
            case .urlDecode:
                return s.contains("%")
            case .base64Decode:
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard t.count >= 4, t.count % 4 == 0 else { return false }
                return t.allSatisfy { c in
                    c.isLetter || c.isNumber || c == "+" || c == "/" || c == "="
                }
            }
        }
    }
}
