import AppKit
import Carbon.HIToolbox

/// Writes a clip back to the pasteboard and (optionally) sends ⌘V to the
/// frontmost app via `CGEvent`. ⌘V synthesis requires the user to grant
/// Lume Accessibility access — without it, the clip is still on the
/// pasteboard and the user can paste manually.
@MainActor
final class PasteInjector {
    private let pasteboard: NSPasteboard

    /// `changeCount` we last wrote ourselves. The PasteboardWatcher
    /// reads this to skip ticks Lume itself caused — without this the
    /// popover-paste path triggers a re-capture, which bumps hitCount
    /// and resets lastSeenAt for the clip you just clicked.
    private(set) var ownedChangeCount: Int? = nil

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Place a clip on the pasteboard.
    func copy(_ clip: Clip) {
        pasteboard.clearContents()
        switch clip.kind {
        case .text, .code:
            if let s = clip.plainText { pasteboard.setString(s, forType: .string) }
        case .rtf:
            if let d = clip.rtfData { pasteboard.setData(d, forType: .rtf) }
            if let s = clip.plainText { pasteboard.setString(s, forType: .string) }
        case .html:
            if let d = clip.htmlData { pasteboard.setData(d, forType: .html) }
            if let s = clip.plainText { pasteboard.setString(s, forType: .string) }
        case .image:
            if let d = clip.imageData {
                pasteboard.setData(d, forType: .tiff)
                pasteboard.setData(d, forType: .png)
            }
        case .file:
            // Only paste paths that still exist; anything missing falls
            // back to plain text so the user gets *something* useful.
            let urls = clip.fileURLArray
            let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !existing.isEmpty {
                pasteboard.writeObjects(existing as [NSPasteboardWriting])
            } else if let s = clip.fileURLs {
                pasteboard.setString(s, forType: .string)
            }
        case .color:
            if let s = clip.colorHex { pasteboard.setString(s, forType: .string) }
        }
        ownedChangeCount = pasteboard.changeCount
    }

    /// Place text on the pasteboard, stripping formatting first.
    func copyAsPlainText(_ clip: Clip) {
        guard let s = clip.plainText else { return }
        copyPlainText(s)
    }

    /// Place a raw string on the pasteboard. The watcher will skip the
    /// resulting changeCount tick because we record `ownedChangeCount`
    /// after the write.
    func copyPlainText(_ s: String) {
        pasteboard.clearContents()
        pasteboard.setString(s, forType: .string)
        ownedChangeCount = pasteboard.changeCount
    }

    /// Manually mark the next pasteboard tick as ours — for callers that
    /// wrote to the pasteboard directly without going through this class.
    func markOwned() {
        ownedChangeCount = pasteboard.changeCount
    }

    /// Synthesize a ⌘V keystroke. Silent no-op if Accessibility is not granted.
    func simulatePaste() {
        guard AXIsProcessTrusted() else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
