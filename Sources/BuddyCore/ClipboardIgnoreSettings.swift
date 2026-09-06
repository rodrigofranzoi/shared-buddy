import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// An app whose pasteboard copies should not enter Clipboard Buddy history.
public struct IgnoredClipboardApp: Identifiable, Codable, Equatable, Sendable, Hashable {
    public var id: String { bundleIdentifier }
    public var bundleIdentifier: String
    public var displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}

/// Persisted list of apps skipped when capturing the clipboard.
public enum ClipboardIgnoreSettings {
    public static let defaultMaxHistoryCount = 200
    public static let defaultMenuBarRecentCount = 10
    public static let defaultMenuBarFavoriteCount = 8

    public static var ignoredApps: [IgnoredClipboardApp] {
        get {
            guard let data = UserDefaults.standard.data(forKey: BuddySettingsKey.clipboardIgnoredApps),
                  let decoded = try? JSONDecoder().decode([IgnoredClipboardApp].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: BuddySettingsKey.clipboardIgnoredApps)
            }
        }
    }

    public static var ignoredBundleIdentifiers: Set<String> {
        Set(ignoredApps.map(\.bundleIdentifier))
    }

    public static func add(_ app: IgnoredClipboardApp) {
        var apps = ignoredApps
        guard !apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        apps.append(app)
        apps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        ignoredApps = apps
    }

    public static func remove(bundleIdentifier: String) {
        ignoredApps = ignoredApps.filter { $0.bundleIdentifier != bundleIdentifier }
    }

    /// Returns `true` when the frontmost app is on the ignore list.
    public static func shouldIgnoreFrontmostApp() -> Bool {
        #if canImport(AppKit)
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return ignoredBundleIdentifiers.contains(bundleID)
        #else
        return false
        #endif
    }

    public static var maxHistoryCount: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.clipboardMaxHistoryCount) as? Int
                ?? defaultMaxHistoryCount,
            min: 10,
            max: 2000
        )
    }

    public static var menuBarRecentCount: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.clipboardMenuBarRecentCount) as? Int
                ?? defaultMenuBarRecentCount,
            min: 1,
            max: 50
        )
    }

    public static var menuBarFavoriteCount: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.clipboardMenuBarFavoriteCount) as? Int
                ?? defaultMenuBarFavoriteCount,
            min: 0,
            max: 50
        )
    }

    public static var screenshotMaxHistoryCount: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.screenshotMaxHistoryCount) as? Int
                ?? 100,
            min: 10,
            max: 2000
        )
    }

    public static var screenshotMenuBarRecentCount: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.screenshotMenuBarRecentCount) as? Int
                ?? 8,
            min: 1,
            max: 50
        )
    }

    private static func clamped(_ value: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(value, min), max)
    }
}
