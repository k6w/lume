import AppKit
import SwiftUI

/// Owns the `NSWindow`s the app can show. Keeps strong references so
/// they aren't deallocated when the user clicks elsewhere.
@MainActor
final class WindowRouter {
    weak var environment: AppEnvironment?
    private var mainWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    init(environment: AppEnvironment?) { self.environment = environment }

    func openMain() {
        guard let environment else { return }
        if let win = mainWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = MainWindowRoot(environment: environment)
        let host = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: host)
        win.title = "Lume"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.titleVisibility = .visible
        win.titlebarAppearsTransparent = false
        win.toolbarStyle = .unified
        win.setContentSize(NSSize(width: 980, height: 640))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = WindowDelegateBridge.shared
        mainWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openOnboarding() {
        guard let environment else { return }
        if let win = onboardingWindow {
            win.makeKeyAndOrderFront(nil)
            return
        }
        let root = OnboardingWindow(environment: environment) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            UserDefaults.standard.set(true, forKey: "lume.onboarding.completed")
        }
        let host = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: host)
        win.title = "Welcome to Lume"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.setContentSize(NSSize(width: 540, height: 580))
        win.center()
        win.isReleasedWhenClosed = false
        onboardingWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeMain() {
        mainWindow?.close()
        mainWindow = nil
    }
}

/// Single shared NSWindowDelegate that just nils out our stored references
/// when the windows close. Keeps the router free of per-window subclassing.
@MainActor
final class WindowDelegateBridge: NSObject, NSWindowDelegate {
    static let shared = WindowDelegateBridge()
    func windowWillClose(_ notification: Notification) { /* references cleared lazily */ }
}
