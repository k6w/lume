import Foundation
import AppKit
import GRDB

/// Polls `NSPasteboard.general.changeCount` every 0.4 s. Only reads when
/// it advances. Capture is gated by `CaptureSettings`:
///   - text + colors + files (path only) are always captured (cheap).
///   - images are opt-in (heavy on disk).
@MainActor
final class PasteboardWatcher {
    private let repository: ClipRepository
    private let sensitivity: SensitivityDetector
    private let encryption: EncryptionService
    private weak var pasteInjector: PasteInjector?
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int

    init(
        repository: ClipRepository,
        sensitivity: SensitivityDetector,
        encryption: EncryptionService,
        pasteInjector: PasteInjector? = nil,
        pasteboard: NSPasteboard = .general
    ) {
        self.repository = repository
        self.sensitivity = sensitivity
        self.encryption = encryption
        self.pasteInjector = pasteInjector
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // Lume just wrote this — popover-paste, main-window Copy, etc.
        // Don't re-capture our own work, that bumps hitCount and resets
        // lastSeenAt for the clip the user just clicked.
        if pasteInjector?.ownedChangeCount == count { return }

        guard let candidate = makeClipFromPasteboard() else { return }

        if let bundleID = candidate.sourceBundleID,
           Self.excludedAppCache.contains(bundleID) {
            return
        }

        // The user can opt out of auto-encryption from the Privacy pane.
        // Default true so first-run still protects passwords picked up
        // from known vaults.
        let encryptSensitive = UserDefaults.standard.object(forKey: "lume.encryptSensitive") as? Bool ?? true
        Task.detached(priority: .utility) { [repository, sensitivity, encryption] in
            var clip = candidate
            if encryptSensitive, sensitivity.isLikelySensitive(clip) {
                clip = encryption.seal(clip)
            }
            do {
                try repository.upsert(clip)
            } catch {
                NSLog("[Lume] upsert failed: \(error)")
            }
        }
    }

    static var excludedAppCache: Set<String> = []

    // MARK: Capture priorities

    /// Walks the pasteboard in priority order. Returns the first match.
    private func makeClipFromPasteboard() -> Clip? {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let now = Date()

        // 1. File URLs — always on. Stores only the path string, no file body.
        if let fileClip = readFileURLs(bundleID: bundleID, now: now) {
            return fileClip
        }

        // 2. NSColor — color picker drops these.
        if let colorClip = readColor(bundleID: bundleID, now: now) {
            return colorClip
        }

        // 3. Image — opt-in, because images bloat the DB.
        if CaptureSettings.captureImages {
            if let imageClip = readImage(bundleID: bundleID, now: now) {
                return imageClip
            }
        }

        // 4. Text (with hex-color promotion). RTF/HTML are kept as text but
        //    we hold their formatted blobs alongside so the user can paste
        //    them back with formatting if they want.
        if let textClip = readText(bundleID: bundleID, now: now) {
            return textClip
        }

        return nil
    }

    // MARK: readers

    private func readFileURLs(bundleID: String?, now: Date) -> Clip? {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard pasteboard.canReadObject(forClasses: [NSURL.self], options: opts) else { return nil }
        let raw = pasteboard.readObjects(forClasses: [NSURL.self], options: opts) ?? []
        let urls: [URL] = raw.compactMap { ($0 as? NSURL) as URL? }
        guard !urls.isEmpty else { return nil }
        let joined = urls.map(\.path).joined(separator: "\n")
        return Clip(
            id: UUID().uuidString,
            contentHash: ContentHasher.hash(kind: .file, payload: Data(joined.utf8)),
            kind: .file,
            plainText: joined,
            rtfData: nil, htmlData: nil, imageData: nil, thumbnailData: nil,
            fileURLs: joined, colorHex: nil, detectedLanguage: nil,
            sourceBundleID: bundleID, byteSize: joined.utf8.count,
            isPinned: false, isEncrypted: false, encryptedBlob: nil,
            createdAt: now, lastSeenAt: now, hitCount: 1
        )
    }

    private func readColor(bundleID: String?, now: Date) -> Clip? {
        guard pasteboard.canReadObject(forClasses: [NSColor.self], options: nil) else { return nil }
        guard let raw = pasteboard.readObjects(forClasses: [NSColor.self], options: nil),
              let color = raw.first as? NSColor,
              let srgb = color.usingColorSpace(.sRGB)
        else { return nil }
        let hex = String(format: "#%02X%02X%02X",
                         Int(srgb.redComponent * 255),
                         Int(srgb.greenComponent * 255),
                         Int(srgb.blueComponent * 255))
        return Clip(
            id: UUID().uuidString,
            contentHash: ContentHasher.hash(kind: .color, payload: Data(hex.utf8)),
            kind: .color,
            plainText: hex,
            rtfData: nil, htmlData: nil, imageData: nil, thumbnailData: nil,
            fileURLs: nil, colorHex: hex, detectedLanguage: nil,
            sourceBundleID: bundleID, byteSize: hex.utf8.count,
            isPinned: false, isEncrypted: false, encryptedBlob: nil,
            createdAt: now, lastSeenAt: now, hitCount: 1
        )
    }

    private func readImage(bundleID: String?, now: Date) -> Clip? {
        // Walk the pasteboard's actual types and accept the first image UTI
        // that yields data. Covers screenshots (.tiff/.png), web copies,
        // and image objects from Preview.
        let imageUTIs: Set<String> = [
            "public.tiff", "public.png", "public.jpeg",
            "public.heic", "com.compuserve.gif", "public.bmp"
        ]
        var data: Data? = nil
        if let types = pasteboard.types {
            for t in types where imageUTIs.contains(t.rawValue) {
                if let d = pasteboard.data(forType: t) { data = d; break }
            }
        }
        // NSImage object fallback (some apps register only the class).
        if data == nil,
           pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let raw = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
           let image = raw.first as? NSImage,
           let tiff = image.tiffRepresentation {
            data = tiff
        }
        guard let blob = data else { return nil }

        let thumb = ImageThumbnailer.thumbnail(from: blob)
        return Clip(
            id: UUID().uuidString,
            contentHash: ContentHasher.hash(kind: .image, payload: blob),
            kind: .image,
            plainText: nil, rtfData: nil, htmlData: nil,
            imageData: blob, thumbnailData: thumb,
            fileURLs: nil, colorHex: nil, detectedLanguage: nil,
            sourceBundleID: bundleID, byteSize: blob.count,
            isPinned: false, isEncrypted: false, encryptedBlob: nil,
            createdAt: now, lastSeenAt: now, hitCount: 1
        )
    }

    private func readText(bundleID: String?, now: Date) -> Clip? {
        guard let s = pasteboard.string(forType: .string), !s.isEmpty else { return nil }
        let kind: ClipKind = HexColorParser.isHexColor(s) ? .color : .text
        let payload = Data(s.utf8)
        return Clip(
            id: UUID().uuidString,
            contentHash: ContentHasher.hash(kind: kind, payload: payload),
            kind: kind,
            plainText: s,
            rtfData: pasteboard.data(forType: .rtf),
            htmlData: pasteboard.data(forType: .html),
            imageData: nil, thumbnailData: nil,
            fileURLs: nil,
            colorHex: kind == .color ? s : nil,
            detectedLanguage: nil,
            sourceBundleID: bundleID, byteSize: payload.count,
            isPinned: false, isEncrypted: false, encryptedBlob: nil,
            createdAt: now, lastSeenAt: now, hitCount: 1
        )
    }
}

enum HexColorParser {
    static func isHexColor(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("#") else { return false }
        let hex = String(t.dropFirst())
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return false }
        return hex.allSatisfy { $0.isHexDigit }
    }
}
