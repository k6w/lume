import Foundation
import AppKit

/// Snippet variable expansion. Replaces `{{date}}`, `{{time}}`, `{{datetime}}`,
/// `{{clipboard}}`, `{{cursor}}` (the cursor token is kept verbatim — UIs
/// can use it for caret placement after paste). Easy to extend.
enum SnippetExpander {
    static func expand(_ body: String) -> String {
        var s = body
        let now = Date()
        let date = now.formatted(.dateTime.year().month().day())
        let time = now.formatted(.dateTime.hour().minute())
        let dateTime = now.formatted(.dateTime.year().month().day().hour().minute())
        s = s.replacingOccurrences(of: "{{date}}", with: date)
        s = s.replacingOccurrences(of: "{{time}}", with: time)
        s = s.replacingOccurrences(of: "{{datetime}}", with: dateTime)
        if let pb = NSPasteboard.general.string(forType: .string) {
            s = s.replacingOccurrences(of: "{{clipboard}}", with: pb)
        }
        return s
    }
}
