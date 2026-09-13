import AppKit
import Foundation
import BuddyLocalization

/// Brand identity for each Buddy app (default accent colors).
public enum BuddyBrand: String, CaseIterable, Sendable {
    case clipboardBuddy
    case screenshotBuddy
    case otpBuddy
    case paintBuddy

    /// Marketing / default theme accents.
    public var defaultAccentHex: String {
        switch self {
        case .clipboardBuddy: return "#10B981"
        case .screenshotBuddy: return "#E85D22"
        case .otpBuddy: return "#3B82F6"
        case .paintBuddy: return "#7C3AED"
        }
    }

    public var displayName: String {
        switch self {
        case .clipboardBuddy: return "ClipLog Buddy"
        case .screenshotBuddy: return "Capture Buddy"
        case .otpBuddy: return "OTP Buddy"
        case .paintBuddy: return "Paint Buddy"
        }
    }

    public var legalApp: BuddyLegalURLs.App {
        switch self {
        case .clipboardBuddy: return .clipboardBuddy
        case .screenshotBuddy: return .screenshotBuddy
        case .otpBuddy: return .otpBuddy
        case .paintBuddy: return .paintBuddy
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
            case .system: return BuddyL10n.string("System")
            case .light: return BuddyL10n.string("Light")
            case .dark: return BuddyL10n.string("Dark")
            }
        }
    }

    /// Brand accents plus a few extras users can pick quickly.
    public static let accentPresets: [String] = [
        BuddyBrand.clipboardBuddy.defaultAccentHex,
        BuddyBrand.screenshotBuddy.defaultAccentHex,
        BuddyBrand.otpBuddy.defaultAccentHex,
        BuddyBrand.paintBuddy.defaultAccentHex,
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

    /// Whether `hex` matches one of the offered theme swatches.
    public static func isAccentPreset(_ hex: String) -> Bool {
        guard let normalized = normalizeHex(hex) else { return false }
        return accentPresets.contains {
            $0.compare(normalized, options: .caseInsensitive) == .orderedSame
        }
    }

    /// Resolved accent hex for the given brand (stored preset or brand default).
    public static func accentHex(for brand: BuddyBrand) -> String {
        let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.appearanceAccentHex)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return brand.defaultAccentHex }
        let normalized = raw.hasPrefix("#") ? raw.uppercased() : "#\(raw.uppercased())"
        if isAccentPreset(normalized) { return normalized }
        return brand.defaultAccentHex
    }

    public static func setAccentHex(_ hex: String, for brand: BuddyBrand) {
        let normalized = normalizeHex(hex) ?? brand.defaultAccentHex
        let resolved = isAccentPreset(normalized) ? normalized : brand.defaultAccentHex
        UserDefaults.standard.set(resolved, forKey: BuddySettingsKey.appearanceAccentHex)
    }

    public static func resetAccent(for brand: BuddyBrand) {
        UserDefaults.standard.set(brand.defaultAccentHex, forKey: BuddySettingsKey.appearanceAccentHex)
    }

    /// Stored accent as a fixed sRGB color (settings swatches).
    public static func accentBaseNSColor(for brand: BuddyBrand) -> NSColor {
        EditorRedactionSettings.nsColor(fromHex: accentHex(for: brand))
    }

    /// Accent for UI tinting — darkens on light chrome / lightens on dark so accents stay readable.
    public static func accentNSColor(for brand: BuddyBrand) -> NSColor {
        let base = accentBaseNSColor(for: brand)
        return NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return contrastBoostedForDarkBackground(base)
            }
            return contrastBoostedForLightBackground(base)
        })
    }

    /// Success / “Copied” feedback green — contrast-safe on light and dark chrome.
    public static var successNSColor: NSColor {
        // Mid green; light/dark boost adjusts toward readable contrast.
        let base = EditorRedactionSettings.nsColor(fromHex: "#16A34A")
        return NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return contrastBoostedForDarkBackground(base)
            }
            return contrastBoostedForLightBackground(base)
        })
    }

    /// Mixes toward white until contrast vs black is clearly readable on dark chrome (~5.5:1).
    static func contrastBoostedForDarkBackground(_ color: NSColor, minimumRatio: CGFloat = 5.5) -> NSColor {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        if contrastRatio(foreground: srgb, background: .black) >= minimumRatio {
            return srgb
        }

        var low: CGFloat = 0
        var high: CGFloat = 1
        var best = srgb
        for _ in 0..<14 {
            let mid = (low + high) / 2
            let candidate = blend(srgb, toward: .white, amount: mid)
            if contrastRatio(foreground: candidate, background: .black) >= minimumRatio {
                best = candidate
                high = mid
            } else {
                low = mid
            }
        }
        return best
    }

    /// Mixes toward black until contrast vs white is clearly readable on light chrome (~5.5:1).
    static func contrastBoostedForLightBackground(_ color: NSColor, minimumRatio: CGFloat = 5.5) -> NSColor {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        if contrastRatio(foreground: srgb, background: .white) >= minimumRatio {
            return srgb
        }

        var low: CGFloat = 0
        var high: CGFloat = 1
        var best = srgb
        for _ in 0..<14 {
            let mid = (low + high) / 2
            let candidate = blend(srgb, toward: .black, amount: mid)
            if contrastRatio(foreground: candidate, background: .white) >= minimumRatio {
                best = candidate
                high = mid
            } else {
                low = mid
            }
        }
        return best
    }

    private static func blend(_ color: NSColor, toward other: NSColor, amount: CGFloat) -> NSColor {
        let a = color.usingColorSpace(.sRGB) ?? color
        let b = other.usingColorSpace(.sRGB) ?? other
        let t = min(max(amount, 0), 1)
        return NSColor(
            srgbRed: a.redComponent + (b.redComponent - a.redComponent) * t,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t,
            alpha: a.alphaComponent
        )
    }

    private static func contrastRatio(foreground: NSColor, background: NSColor) -> CGFloat {
        let l1 = relativeLuminance(foreground)
        let l2 = relativeLuminance(background)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: NSColor) -> CGFloat {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        func linearize(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linearize(srgb.redComponent)
        let g = linearize(srgb.greenComponent)
        let b = linearize(srgb.blueComponent)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
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
