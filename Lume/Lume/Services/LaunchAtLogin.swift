import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp`. The macOS 13+ replacement
/// for the old SMLoginItem dance — registration is owned by the system
/// and persists across launches, so we don't have to re-arm on boot.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Try to register/unregister and return the actual resulting state.
    /// Failures are logged; the caller should rebind any UI to the
    /// returned value so the toggle never desyncs from reality.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[Lume] launchAtLogin toggle failed: \(error)")
        }
        return isEnabled
    }
}
