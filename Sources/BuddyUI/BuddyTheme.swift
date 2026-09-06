import AppKit
import SwiftUI

/// Design tokens for the *-buddy suite. Apps must use these instead of ad-hoc styling.
/// Accent defaults come from ``BuddyBrand`` / ``BuddyAppearanceSettings`` (user-overridable).
public enum BuddyTheme {
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 6
        public static let lg: CGFloat = 10
        public static let xl: CGFloat = 14
    }

    public enum Duration {
        public static let quick: Double = 0.15
        public static let standard: Double = 0.25

        public static func value(_ base: Double) -> Double {
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return 0 }
            return base
        }
    }

    public enum BuddyColor {
        public static let background = Color(nsColor: .windowBackgroundColor)
        public static let surface = Color(nsColor: .controlBackgroundColor)
        public static let surfaceElevated = Color(nsColor: .underPageBackgroundColor)
        public static let textPrimary = Color(nsColor: .labelColor)
        public static let textSecondary = Color(nsColor: .secondaryLabelColor)
        public static let accent = Color.accentColor
        public static let danger = Color(nsColor: .systemRed)
        public static let border = Color(nsColor: .separatorColor)
        public static let chipFill = Color(nsColor: .quaternaryLabelColor).opacity(0.25)
        public static let chipBorder = Color(nsColor: .tertiaryLabelColor)
    }

    public enum Typography {
        public static var title: Font { .title3.weight(.semibold) }
        public static var body: Font { .body }
        public static var caption: Font { .caption }
        public static var label: Font { .caption.weight(.semibold) }
    }
}
