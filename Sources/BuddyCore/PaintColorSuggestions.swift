import AppKit
import Foundation

/// Suggested relative and harmony colors derived from a base color (HSB).
public struct PaintColorSuggestion: Identifiable, Equatable {
    public enum Kind: String {
        case darker
        case lighter
        case complementary
        case analogous
        case muted
    }

    public var id: String { "\(kind.rawValue)-\(hex)" }
    public let kind: Kind
    public let label: String
    public let hex: String
    public let color: NSColor

    public init(kind: Kind, label: String, color: NSColor) {
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

        func make(
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
            return PaintColorSuggestion(kind: kind, label: label, color: c)
        }

        var results: [PaintColorSuggestion] = [
            make(kind: .darker, label: "Darker", h: hue, s: saturation, b: brightness * 0.8),
            make(kind: .darker, label: "Much darker", h: hue, s: saturation, b: brightness * 0.6),
            make(kind: .lighter, label: "Lighter", h: hue, s: saturation, b: min(1, brightness + 0.2)),
            make(kind: .lighter, label: "Much lighter", h: hue, s: saturation, b: min(1, brightness + 0.4)),
            make(kind: .complementary, label: "Complementary", h: hue + 0.5, s: saturation, b: brightness),
            make(kind: .analogous, label: "Analogous −", h: hue - 30.0 / 360.0, s: saturation, b: brightness),
            make(kind: .analogous, label: "Analogous +", h: hue + 30.0 / 360.0, s: saturation, b: brightness),
            make(kind: .muted, label: "Muted", h: hue, s: saturation * 0.45, b: brightness)
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
