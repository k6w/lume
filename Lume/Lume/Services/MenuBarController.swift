import AppKit
import SwiftUI

/// AppKit shell for the menu-bar status item.
///
/// Click model: **instant**. A single click opens the popover with no
/// discrimination delay. Right-click opens a context menu (Open Lume,
/// Pause/Resume, Quit). The popover's own footer button opens the
/// main window — there's no longer a double-click gesture.
@MainActor
final class MenuBarController: NSObject {
    weak var environment: AppEnvironment?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var hostingController: NSHostingController<PopoverRoot>?

    init(environment: AppEnvironment?) {
        self.environment = environment
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarTemplate")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Lume — A clipboard, lit."
        }
        popover.behavior = .transient
        popover.animates = true
    }

    /// Build and warm the SwiftUI hosting view ahead of the first click,
    /// so the popover renders in one frame.
    func prewarmPopover() {
        guard hostingController == nil, let environment else { return }
        let root = PopoverRoot(
            clipRepository: environment.clipRepository,
            snippetRepository: environment.snippetRepository,
            fts: FullTextSearch(database: environment.database),
            onPaste: { [weak self] clip in self?.paste(clip) },
            onPin: { [weak self] clip in self?.togglePin(clip) },
            onDelete: { [weak self] clip in self?.delete(clip) },
            onOpenMain: { [weak self] in self?.openMainWindow() },
            onSnippetPaste: { [weak self] snippet in self?.pasteSnippet(snippet) }
        )
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = [.preferredContentSize]
        hostingController = controller
        popover.contentViewController = controller
    }

    @objc private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { togglePopover(); return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
            return
        }
        // Instant: no delay, no double-click discrimination.
        togglePopover()
    }

    func showPopoverFromHotkey() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        prewarmPopover()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func openMainWindow() {
        popover.performClose(nil)
        environment?.windows.openMain()
    }

    private func paste(_ clip: Clip) {
        environment?.pasteInjector.copy(clip)
        popover.performClose(nil)
        environment?.pasteInjector.simulatePaste()
    }

    private func togglePin(_ clip: Clip) {
        try? environment?.clipRepository.setPinned(!clip.isPinned, id: clip.id)
    }

    private func delete(_ clip: Clip) {
        try? environment?.clipRepository.delete(id: clip.id)
    }

    private func pasteSnippet(_ snippet: Snippet) {
        let expanded = SnippetExpander.expand(snippet.body)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(expanded, forType: .string)
        popover.performClose(nil)
        environment?.pasteInjector.simulatePaste()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Lume…", action: #selector(menuOpenMain), keyEquivalent: "").target = self
        let settings = menu.addItem(withTitle: "Settings…", action: #selector(menuOpenMain), keyEquivalent: ",")
        settings.target = self
        settings.keyEquivalentModifierMask = [.command]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Pause Capture",  action: #selector(menuPause),  keyEquivalent: "").target = self
        menu.addItem(withTitle: "Resume Capture", action: #selector(menuResume), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Lume", action: #selector(menuQuit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuOpenMain() { openMainWindow() }
    @objc private func menuPause()    { environment?.pasteboardWatcher.stop() }
    @objc private func menuResume()   { environment?.pasteboardWatcher.start() }
    @objc private func menuQuit()     { NSApp.terminate(nil) }
}
