import AppKit
import Foundation
import ServiceManagement
import BuddyLocalization

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

/// Wraps `SMAppService`. Launch-at-login stays **off** until the user consents
/// (Mac App Store Guideline 2.4.5(iii) — no auto-launch without consent).
public enum BuddyLaunchAtLogin {
    public static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: BuddySettingsKey.launchAtLogin)
    }

    /// `true` until the user has answered the first-launch prompt or changed Settings.
    public static var needsConsentPrompt: Bool {
        UserDefaults.standard.object(forKey: BuddySettingsKey.launchAtLoginConfigured) == nil
    }

    /// On first launch after install, record defaults with launch-at-login **off** (no UI).
    /// Prefer `promptForConsentIfNeeded(appDisplayName:)` for interactive installs.
    @discardableResult
    public static func configureDefaultsOnFirstInstall() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: BuddySettingsKey.launchAtLoginConfigured) != nil {
            return isEnabled
        }
        defaults.set(true, forKey: BuddySettingsKey.launchAtLoginConfigured)
        defaults.set(false, forKey: BuddySettingsKey.launchAtLogin)
        return false
    }

    /// First-launch consent popup. Registers as a Login Item only if the user chooses
    /// **Open at Login**. Default button is **Not Now** (stays off).
    @MainActor
    @discardableResult
    public static func promptForConsentIfNeeded(appDisplayName: String) -> Bool {
        if !needsConsentPrompt {
            return isEnabled
        }
        if BuddyMarketingCapture.isEnabled {
            return configureDefaultsOnFirstInstall()
        }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = String(
            localized: "Open \(appDisplayName) when you log in?",
            bundle: BuddyL10n.bundle
        )
        alert.informativeText = BuddyL10n.string(
            "You can change this anytime in Settings. The app will not open at login unless you choose to."
        )
        alert.alertStyle = .informational
        // First button is the Return-key default — keep launch-at-login off unless intentional.
        alert.addButton(withTitle: BuddyL10n.string("Not Now"))
        alert.addButton(withTitle: BuddyL10n.string("Open at Login"))

        let enable = alert.runModal() == .alertSecondButtonReturn
        do {
            try setEnabled(enable)
            return enable
        } catch {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: BuddySettingsKey.launchAtLoginConfigured)
            defaults.set(false, forKey: BuddySettingsKey.launchAtLogin)
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
    /// Does **not** set `launchAtLoginConfigured` — that flag means the user already answered the consent prompt
    /// (or changed the Settings toggle). Marking it here would skip the first-launch popup.
    public static func refreshFromSystem() {
        guard #available(macOS 13.0, *) else { return }
        let enabled = SMAppService.mainApp.status == .enabled
        UserDefaults.standard.set(enabled, forKey: BuddySettingsKey.launchAtLogin)
    }
}
