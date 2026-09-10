import AppKit
import Foundation
import BuddyLocalization

/// Suggested relative and harmony colors derived from a base color (HSB).
public struct PaintColorSuggestion: Identifiable, Equatable {
    public enum Kind: String {
        case darker
        case lighter
        case complementary
        case analogous
        case muted
    }

    /// Stable unique id (kind+hex alone can collide when lighter/darker steps clamp to the same color).
    public let id: String
    public let kind: Kind
    public let label: String
    public let hex: String
    public let color: NSColor

    public init(id: String, kind: Kind, label: String, color: NSColor) {
        self.id = id
        self.kind = kind
        self.label = label
        let converted = color.usingColorSpace(.sRGB) ?? color
        self.color = converted
        self.hex = EditorRedactionSettings.hex(from: converted)
    }
}

public enum PaintColorSuggestions {
    /// Relatives (darker / lighter) plus complementary, analogous, and muted variants.
    public static func suggestions(from color: NSColor) -> [PaintColorSuggestion] {
        let base = color.usingColorSpace(.sRGB) ?? color
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        func L(_ key: String.LocalizationValue) -> String {
            String(localized: key, bundle: BuddyL10n.bundle)
        }

        func make(
            index: Int,
            kind: PaintColorSuggestion.Kind,
            label: String,
            h: CGFloat,
            s: CGFloat,
            b: CGFloat
        ) -> PaintColorSuggestion {
            let c = NSColor(
                hue: wrapHue(h),
                saturation: clamp01(s),
                brightness: clamp01(b),
                alpha: alpha
            )
            let hex = EditorRedactionSettings.hex(from: c.usingColorSpace(.sRGB) ?? c)
            return PaintColorSuggestion(
                id: "\(index)-\(kind.rawValue)-\(hex)",
                kind: kind,
                label: label,
                color: c
            )
        }

        var results: [PaintColorSuggestion] = [
            make(index: 0, kind: .darker, label: L("Darker"), h: hue, s: saturation, b: brightness * 0.8),
            make(index: 1, kind: .darker, label: L("Much darker"), h: hue, s: saturation, b: brightness * 0.6),
            make(index: 2, kind: .lighter, label: L("Lighter"), h: hue, s: saturation, b: min(1, brightness + 0.2)),
            make(index: 3, kind: .lighter, label: L("Much lighter"), h: hue, s: saturation, b: min(1, brightness + 0.4)),
            make(index: 4, kind: .complementary, label: L("Complementary"), h: hue + 0.5, s: saturation, b: brightness),
            make(index: 5, kind: .analogous, label: L("Analogous −"), h: hue - 30.0 / 360.0, s: saturation, b: brightness),
            make(index: 6, kind: .analogous, label: L("Analogous +"), h: hue + 30.0 / 360.0, s: saturation, b: brightness),
            make(index: 7, kind: .muted, label: L("Muted"), h: hue, s: saturation * 0.45, b: brightness)
        ]

        // Drop near-duplicates of the base hex (e.g. already very dark/light).
        let baseHex = EditorRedactionSettings.hex(from: base).uppercased()
        results = results.filter { $0.hex.uppercased() != baseHex }
        return results
    }

    private static func wrapHue(_ value: CGFloat) -> CGFloat {
        var h = value.truncatingRemainder(dividingBy: 1)
        if h < 0 { h += 1 }
        return h
    }

    private static func clamp01(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
