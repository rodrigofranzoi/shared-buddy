import Foundation
import ServiceManagement

public enum BuddyLaunchAtLoginError: Error, LocalizedError {
    case unsupported
    case registrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Launch at login requires macOS 13 or later."
        case .registrationFailed(let message):
            return message
        }
    }
}

/// Wraps `SMAppService` and defaults launch-at-login **on** for first install.
public enum BuddyLaunchAtLogin {
    public static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: BuddySettingsKey.launchAtLogin)
    }

    /// On first launch after install, turn launch-at-login on and register with the system.
    @discardableResult
    public static func enableByDefaultOnFirstInstall() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: BuddySettingsKey.launchAtLoginConfigured) != nil {
            return isEnabled
        }
        defaults.set(true, forKey: BuddySettingsKey.launchAtLoginConfigured)
        do {
            try setEnabled(true)
            return true
        } catch {
            // Still record the preference; registration can be retried from Settings.
            defaults.set(true, forKey: BuddySettingsKey.launchAtLogin)
            return false
        }
    }

    public static func setEnabled(_ enabled: Bool) throws {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: BuddySettingsKey.launchAtLoginConfigured)
        defaults.set(enabled, forKey: BuddySettingsKey.launchAtLogin)

        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else if service.status == .enabled {
                    try service.unregister()
                }
            } catch {
                throw BuddyLaunchAtLoginError.registrationFailed(error.localizedDescription)
            }
        } else {
            throw BuddyLaunchAtLoginError.unsupported
        }
    }

    /// Syncs UserDefaults with the real Login Item status (e.g. after the user changes it in System Settings).
    public static func refreshFromSystem() {
        guard #available(macOS 13.0, *) else { return }
        let enabled = SMAppService.mainApp.status == .enabled
        UserDefaults.standard.set(enabled, forKey: BuddySettingsKey.launchAtLogin)
        if UserDefaults.standard.object(forKey: BuddySettingsKey.launchAtLoginConfigured) == nil {
            UserDefaults.standard.set(true, forKey: BuddySettingsKey.launchAtLoginConfigured)
        }
    }
}
