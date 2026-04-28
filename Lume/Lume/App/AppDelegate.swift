import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let environment = AppEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply the persisted Dock-visibility preference. Info.plist has
        // LSUIElement=true so we boot as .accessory; flip to .regular if
        // the user opted to show the Dock icon.
        if UserDefaults.standard.bool(forKey: "lume.showInDock") {
            NSApp.setActivationPolicy(.regular)
        }

        environment.menuBar.install()
        environment.menuBar.prewarmPopover()

        Task.detached(priority: .utility) { [environment] in
            await environment.bootBackgroundServices()
        }

        if !UserDefaults.standard.bool(forKey: "lume.onboarding.completed") {
            environment.windows.openOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.shutdown()
    }
}

@MainActor
final class AppEnvironment {
    let database: AppDatabase
    let clipRepository: ClipRepository
    let snippetRepository: SnippetRepository
    let tagRepository: TagRepository
    let pasteboardWatcher: PasteboardWatcher
    let menuBar: MenuBarController
    let hotKey: HotKeyService
    let pasteInjector: PasteInjector
    let encryption: EncryptionService
    let sensitivity: SensitivityDetector
    let purge: PurgeScheduler
    let cloud: CloudSyncEngine
    let updateChecker: UpdateChecker
    let windows: WindowRouter

    init() {
        let db = try! AppDatabase.shared()
        self.database = db
        let clips = ClipRepository(database: db)
        self.clipRepository = clips
        self.snippetRepository = SnippetRepository(database: db)
        self.tagRepository = TagRepository(database: db)
        self.encryption = EncryptionService()
        self.sensitivity = SensitivityDetector()
        self.pasteInjector = PasteInjector(encryption: encryption)
        self.pasteboardWatcher = PasteboardWatcher(
            repository: clips,
            sensitivity: sensitivity,
            encryption: encryption,
            pasteInjector: pasteInjector
        )
        self.purge = PurgeScheduler(repository: clips)
        self.cloud = CloudSyncEngine(database: db, repository: clips, encryption: encryption)
        self.updateChecker = UpdateChecker()
        self.hotKey = HotKeyService()
        self.windows = WindowRouter(environment: nil)
        self.menuBar = MenuBarController(environment: nil)

        // Wire two-way references after init.
        self.windows.environment = self
        self.menuBar.environment = self
    }

    func bootBackgroundServices() async {
        pasteboardWatcher.start()
        purge.start()
        await cloud.start()
        hotKey.start { [weak self] in
            Task { @MainActor in self?.menuBar.showPopoverFromHotkey() }
        }
        // Check for updates a beat after boot, then once a day.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self?.updateChecker.check()
        }
    }

    func shutdown() {
        pasteboardWatcher.stop()
        purge.stop()
        hotKey.unregisterAll()
    }
}
