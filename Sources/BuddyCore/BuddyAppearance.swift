import AppKit
import Foundation

/// Brand identity for each Buddy app (default accent colors).
public enum BuddyBrand: String, CaseIterable, Sendable {
    case clipboardBuddy
    case screenshotBuddy
    case otpBuddy

    /// Marketing / default theme accents.
    public var defaultAccentHex: String {
        switch self {
        case .clipboardBuddy: return "#10B981"
        case .screenshotBuddy: return "#E85D22"
        case .otpBuddy: return "#3B82F6"
        }
    }

    public var displayName: String {
        switch self {
        case .clipboardBuddy: return "Clipboard Buddy"
        case .screenshotBuddy: return "Screenshot Buddy"
        case .otpBuddy: return "OTP Buddy"
        }
    }

    public var legalApp: BuddyLegalURLs.App {
        switch self {
        case .clipboardBuddy: return .clipboardBuddy
        case .screenshotBuddy: return .screenshotBuddy
        case .otpBuddy: return .otpBuddy
        }
    }
}

/// Persisted appearance preferences (color scheme + accent).
public enum BuddyAppearanceSettings {
    public enum ColorSchemePreference: String, CaseIterable, Sendable {
        case system
        case light
        case dark

        public var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    /// Brand accents plus a few extras users can pick quickly.
    public static let accentPresets: [String] = [
        BuddyBrand.clipboardBuddy.defaultAccentHex,
        BuddyBrand.screenshotBuddy.defaultAccentHex,
        BuddyBrand.otpBuddy.defaultAccentHex,
        "#8B5CF6",
        "#EC4899",
        "#14B8A6",
        "#F59E0B",
        "#64748B"
    ]

    public static var colorSchemePreference: ColorSchemePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.appearanceColorScheme) ?? ""
            return ColorSchemePreference(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: BuddySettingsKey.appearanceColorScheme)
            applyAppKitAppearance()
        }
    }

    /// Resolved accent hex for the given brand (stored override or brand default).
    public static func accentHex(for brand: BuddyBrand) -> String {
        let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.appearanceAccentHex)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return brand.defaultAccentHex }
        return raw.hasPrefix("#") ? raw.uppercased() : "#\(raw.uppercased())"
    }

    public static func setAccentHex(_ hex: String, for brand: BuddyBrand) {
        let normalized = normalizeHex(hex) ?? brand.defaultAccentHex
        UserDefaults.standard.set(normalized, forKey: BuddySettingsKey.appearanceAccentHex)
    }

    public static func resetAccent(for brand: BuddyBrand) {
        UserDefaults.standard.set(brand.defaultAccentHex, forKey: BuddySettingsKey.appearanceAccentHex)
    }

    public static func accentNSColor(for brand: BuddyBrand) -> NSColor {
        EditorRedactionSettings.nsColor(fromHex: accentHex(for: brand))
    }

    /// Syncs `NSApp.appearance` from stored preference (menu bar + AppKit chrome).
    public static func applyAppKitAppearance() {
        switch colorSchemePreference {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    public static func normalizeHex(_ token: String) -> String? {
        var cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, UInt64(cleaned, radix: 16) != nil else { return nil }
        return "#\(cleaned)"
    }
}
