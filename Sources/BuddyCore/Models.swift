import AppKit
import Foundation

public struct FavoriteShortcut: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var content: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.content = content
        self.createdAt = createdAt
    }
}

/// One pasteboard flavor (UTI / `NSPasteboard.PasteboardType`) and its payload.
public struct ClipboardRepresentation: Codable, Sendable, Equatable {
    public var type: String
    public var data: Data

    public init(type: String, data: Data) {
        self.type = type
        self.data = data
    }
}

public struct ClipboardHistoryItem: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var text: String?
    public var imageData: Data?
    /// All captured pasteboard flavors for faithful restore.
    public var representations: [ClipboardRepresentation]
    /// Absolute paths when the clipboard held file URLs (Finder copy, etc.).
    public var filePaths: [String]
    public var tags: [ContentTag]
    public var isSensitive: Bool
    public var createdAt: Date
    public var isFavorite: Bool
    /// On-device OCR text from `imageData`, used for history search.
    public var ocrText: String

    public init(
        id: UUID = UUID(),
        text: String? = nil,
        imageData: Data? = nil,
        representations: [ClipboardRepresentation] = [],
        filePaths: [String] = [],
        tags: [ContentTag] = [],
        isSensitive: Bool = false,
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        ocrText: String = ""
    ) {
        self.id = id
        self.text = text
        self.imageData = imageData
        self.representations = representations
        self.filePaths = filePaths
        self.tags = tags
        self.isSensitive = isSensitive
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.ocrText = ocrText
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        representations = try c.decodeIfPresent([ClipboardRepresentation].self, forKey: .representations) ?? []
        filePaths = try c.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        tags = try c.decode([ContentTag].self, forKey: .tags)
        isSensitive = try c.decode(Bool.self, forKey: .isSensitive)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isFavorite = try c.decode(Bool.self, forKey: .isFavorite)
        ocrText = try c.decodeIfPresent(String.self, forKey: .ocrText) ?? ""
    }

    public var preview: String {
        if let text, !text.isEmpty {
            return String(text.prefix(80))
        }
        if imageData != nil { return "Image" }
        if !filePaths.isEmpty {
            return filePaths
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
        }
        if representations.contains(where: {
            let t = $0.type.lowercased()
            return t.contains("rtf") || t.contains("html")
        }) {
            return "Rich Text"
        }
        if representations.contains(where: { $0.type.lowercased().contains("pdf") }) {
            return "PDF"
        }
        if let type = representations.first?.type {
            return URL(fileURLWithPath: type).pathExtension.isEmpty ? type : type
        }
        return "Empty"
    }

    /// Leading swatch for list rows when the item is (or contains) a color token.
    public var listColor: NSColor? {
        guard imageData == nil, let text, !text.isEmpty else { return nil }
        if let token = DetectedContentExtractor.extractTokens(from: text, limit: 4)
            .first(where: { $0.kind == .color })
        {
            return token.nsColor
        }
        guard tags.contains(.colorHex) else { return nil }
        return EditorRedactionSettings.nsColor(fromColorToken: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Openable URL for list rows when the item is (or contains) a link.
    public var listOpenableURL: URL? {
        guard let text, !text.isEmpty else { return nil }
        if let url = DetectedContentExtractor.extractTokens(from: text, limit: 4)
            .first(where: { $0.kind == .url })?
            .openableURL
        {
            return url
        }
        return DetectedContentToken.openableURL(from: text)
    }
}

public struct ScreenshotItem: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var imageData: Data
    public var title: String
    public var notes: String
    public var tags: [ContentTag]
    public var createdAt: Date
    public var redactionRects: [RedactionRect]
    public var drawStrokes: [DrawStroke]
    public var annotations: [ImageAnnotation]
    /// Per-screenshot Auto-blur type selection (`ContentTag.rawValue`). Empty → none selected.
    public var autoBlurTagValues: [String]
    /// On-device OCR text from the image, used for gallery search.
    public var ocrText: String

    public init(
        id: UUID = UUID(),
        imageData: Data,
        title: String = "Screenshot",
        notes: String = "",
        tags: [ContentTag] = [.image],
        createdAt: Date = Date(),
        redactionRects: [RedactionRect] = [],
        drawStrokes: [DrawStroke] = [],
        annotations: [ImageAnnotation] = [],
        autoBlurTagValues: [String] = [],
        ocrText: String = ""
    ) {
        self.id = id
        self.imageData = imageData
        self.title = title
        self.notes = notes
        self.tags = tags
        self.createdAt = createdAt
        self.redactionRects = redactionRects
        self.drawStrokes = drawStrokes
        self.annotations = annotations
        self.autoBlurTagValues = autoBlurTagValues
        self.ocrText = ocrText
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        imageData = try c.decode(Data.self, forKey: .imageData)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decode(String.self, forKey: .notes)
        tags = try c.decode([ContentTag].self, forKey: .tags)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        redactionRects = try c.decodeIfPresent([RedactionRect].self, forKey: .redactionRects) ?? []
        drawStrokes = try c.decodeIfPresent([DrawStroke].self, forKey: .drawStrokes) ?? []
        annotations = try c.decodeIfPresent([ImageAnnotation].self, forKey: .annotations) ?? []
        autoBlurTagValues = try c.decodeIfPresent([String].self, forKey: .autoBlurTagValues) ?? []
        ocrText = try c.decodeIfPresent(String.self, forKey: .ocrText) ?? ""
    }

    /// Tags used for Auto-blur on this screenshot. Empty means none selected.
    public var autoBlurTags: Set<ContentTag> {
        get {
            Set(autoBlurTagValues.compactMap(ContentTag.init(rawValue:)))
                .intersection(ContentTagger.sensitiveTags)
        }
        set {
            autoBlurTagValues = newValue
                .intersection(ContentTagger.sensitiveTags)
                .map(\.rawValue)
                .sorted()
        }
    }
}

public struct RedactionRect: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var style: RedactionStyle
    public var borderEnabled: Bool
    public var borderColorHex: String
    public var borderWidth: Double
    /// Fill color for rectangle (black-box) style.
    public var fillColorHex: String
    /// Fill opacity for rectangle style (0…1).
    public var fillOpacity: Double
    /// When false, rectangle has no fill (border-only when border is on).
    public var fillEnabled: Bool
    /// Blur strength captured when this redaction was created (SwiftUI-like soft blur).
    public var blurRadius: Double

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        style: RedactionStyle = .blackBox,
        borderEnabled: Bool = false,
        borderColorHex: String = "#FFFFFF",
        borderWidth: Double = 3,
        fillColorHex: String = "#000000",
        fillOpacity: Double = 1,
        fillEnabled: Bool = true,
        blurRadius: Double = 10
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.style = style
        self.borderEnabled = borderEnabled
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.fillColorHex = fillColorHex
        self.fillOpacity = fillOpacity
        self.fillEnabled = fillEnabled
        self.blurRadius = blurRadius
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        width = try c.decode(Double.self, forKey: .width)
        height = try c.decode(Double.self, forKey: .height)
        style = try c.decode(RedactionStyle.self, forKey: .style)
        borderEnabled = try c.decodeIfPresent(Bool.self, forKey: .borderEnabled) ?? false
        borderColorHex = try c.decodeIfPresent(String.self, forKey: .borderColorHex) ?? "#FFFFFF"
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 3
        fillColorHex = try c.decodeIfPresent(String.self, forKey: .fillColorHex) ?? "#000000"
        fillOpacity = try c.decodeIfPresent(Double.self, forKey: .fillOpacity) ?? 1
        fillEnabled = try c.decodeIfPresent(Bool.self, forKey: .fillEnabled) ?? true
        blurRadius = try c.decodeIfPresent(Double.self, forKey: .blurRadius) ?? 10
    }
}

public enum RedactionStyle: String, Codable, Sendable {
    case blackBox
    case blur
}

/// Freehand ink stroke in normalized image coordinates (origin top-left).
public struct DrawStroke: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var points: [DrawPoint]
    public var colorHex: String
    /// Stroke width in image points.
    public var lineWidth: Double

    public init(
        id: UUID = UUID(),
        points: [DrawPoint],
        colorHex: String = "#FF3B30",
        lineWidth: Double = 4
    ) {
        self.id = id
        self.points = points
        self.colorHex = colorHex
        self.lineWidth = lineWidth
    }
}

public struct DrawPoint: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum ImageAnnotationKind: String, Codable, Sendable {
    case arrow
    case ellipse
    case text
}

/// Overlay annotations (arrows, ellipses, text stamps) in normalized top-left coordinates.
public struct ImageAnnotation: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: ImageAnnotationKind
    /// Start / origin X (0…1).
    public var x: Double
    /// Start / origin Y (0…1).
    public var y: Double
    /// End X for arrows, or width for ellipse/text box.
    public var x2: Double
    /// End Y for arrows, or height for ellipse/text box.
    public var y2: Double
    public var text: String
    public var colorHex: String
    public var lineWidth: Double
    public var fontSize: Double
    public var fillEnabled: Bool
    public var fillOpacity: Double

    public init(
        id: UUID = UUID(),
        kind: ImageAnnotationKind,
        x: Double,
        y: Double,
        x2: Double,
        y2: Double,
        text: String = "",
        colorHex: String = "#FF3B30",
        lineWidth: Double = 3,
        fontSize: Double = 18,
        fillEnabled: Bool = false,
        fillOpacity: Double = 0.2
    ) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.x2 = x2
        self.y2 = y2
        self.text = text
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.fillEnabled = fillEnabled
        self.fillOpacity = fillOpacity
    }
}

public enum BuddySettingsKey {
    public static let autoCopyOTP = "buddy.otp.autoCopy"
    public static let clipboardRetentionDays = "buddy.clipboard.retentionDays"
    /// Max clipboard history items to keep (newest first).
    public static let clipboardMaxHistoryCount = "buddy.clipboard.maxHistoryCount"
    /// How many recent clippings appear in the menu bar.
    public static let clipboardMenuBarRecentCount = "buddy.clipboard.menuBarRecentCount"
    /// How many favorites appear in the menu bar.
    public static let clipboardMenuBarFavoriteCount = "buddy.clipboard.menuBarFavoriteCount"
    /// JSON array of `{bundleIdentifier, displayName}` apps whose copies are not saved.
    public static let clipboardIgnoredApps = "buddy.clipboard.ignoredApps"
    /// Max screenshot gallery items to keep (newest first).
    public static let screenshotMaxHistoryCount = "buddy.screenshot.maxHistoryCount"
    /// How many recent screenshots appear in the menu bar.
    public static let screenshotMenuBarRecentCount = "buddy.screenshot.menuBarRecentCount"
    public static let launchAtLogin = "buddy.launchAtLogin"
    /// Marks that launch-at-login was configured (first install defaults to on).
    public static let launchAtLoginConfigured = "buddy.launchAtLoginConfigured"
    /// Persisted timed pause end (`timeIntervalSince1970`). Absent / 0 = not paused.
    public static let pauseUntil = "buddy.pauseUntil"
    /// When true, monitoring stays off across launches until the user resumes.
    public static let pausePermanently = "buddy.pausePermanently"
    /// When true, adult-content block still applies but the toolbar warning is suppressed.
    public static let contentWarningNeverShow = "buddy.content.warningNeverShow"
    /// Blur passwords, IBANs, cards, API keys, OTPs, and similar in UI lists.
    public static let blurSensitiveContent = "buddy.privacy.blurSensitiveContent"
    /// Require Touch ID / Mac password before revealing sensitive content.
    public static let requireAuthSensitiveContent = "buddy.privacy.requireAuthSensitiveContent"
    /// Raw `ContentTag` values locked behind password / Touch ID in previews.
    public static let protectedContentTags = "buddy.privacy.protectedContentTags"
    /// Raw `ContentTag` values detected by screenshot Auto-blur.
    public static let autoBlurContentTags = "buddy.privacy.autoBlurContentTags"
    /// Soft blur radius matching preview-style SwiftUI blur (default 10).
    public static let editorBlurRadius = "buddy.screenshot.editorBlurRadius"
    /// Opacity (0…1) for screenshot editor black-box tool (default 1).
    public static let editorBlackBoxOpacity = "buddy.screenshot.editorBlackBoxOpacity"
    /// Hex RGB for black-box fill, e.g. `#000000` (default black).
    public static let editorBlackBoxColor = "buddy.screenshot.editorBlackBoxColor"
    public static let editorFillEnabled = "buddy.screenshot.editorFillEnabled"
    public static let editorBorderEnabled = "buddy.screenshot.editorBorderEnabled"
    public static let editorBorderColor = "buddy.screenshot.editorBorderColor"
    public static let editorBorderWidth = "buddy.screenshot.editorBorderWidth"
    public static let editorDrawColor = "buddy.screenshot.editorDrawColor"
    public static let editorDrawSize = "buddy.screenshot.editorDrawSize"
    /// Collapse the editor tools panel.
    public static let editorToolsCollapsed = "buddy.screenshot.editorToolsCollapsed"
    /// Appearance mode: `system` | `light` | `dark`.
    public static let appearanceColorScheme = "buddy.appearance.colorScheme"
    /// User accent color as `#RRGGBB`. Empty means use the app brand default.
    public static let appearanceAccentHex = "buddy.appearance.accentHex"
}

/// Brush preferences for the screenshot editor redaction tools.
public enum EditorRedactionSettings {
    public static var blurRadius: Double {
        let value = UserDefaults.standard.object(forKey: BuddySettingsKey.editorBlurRadius) as? Double
        // Matches SensitiveBlurView preview softness (~10).
        return min(max(value ?? 10, 2), 40)
    }

    public static var blackBoxOpacity: Double {
        let value = UserDefaults.standard.object(forKey: BuddySettingsKey.editorBlackBoxOpacity) as? Double
        return min(max(value ?? 1, 0.05), 1)
    }

    public static var blackBoxColorHex: String {
        let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.editorBlackBoxColor) ?? "#000000"
        return raw.hasPrefix("#") ? raw : "#\(raw)"
    }

    public static var blackBoxNSColor: NSColor {
        nsColor(fromHex: blackBoxColorHex).withAlphaComponent(blackBoxOpacity)
    }

    public static var fillEnabled: Bool {
        if UserDefaults.standard.object(forKey: BuddySettingsKey.editorFillEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: BuddySettingsKey.editorFillEnabled)
    }

    public static var borderEnabled: Bool {
        if UserDefaults.standard.object(forKey: BuddySettingsKey.editorBorderEnabled) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: BuddySettingsKey.editorBorderEnabled)
    }

    public static var borderColorHex: String {
        let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.editorBorderColor) ?? "#FFFFFF"
        return raw.hasPrefix("#") ? raw : "#\(raw)"
    }

    public static var borderWidth: Double {
        let value = UserDefaults.standard.object(forKey: BuddySettingsKey.editorBorderWidth) as? Double
        return min(max(value ?? 3, 1), 24)
    }

    public static var drawColorHex: String {
        let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.editorDrawColor) ?? "#FF3B30"
        return raw.hasPrefix("#") ? raw : "#\(raw)"
    }

    public static var drawSize: Double {
        let value = UserDefaults.standard.object(forKey: BuddySettingsKey.editorDrawSize) as? Double
        return min(max(value ?? 4, 1), 48)
    }

    public static func nsColor(fromHex hex: String) -> NSColor {
        nsColor(fromColorToken: hex) ?? .black
    }

    /// Parses `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb(...)`, or `rgba(...)`. Returns nil if invalid.
    public static func nsColor(fromColorToken token: String) -> NSColor? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("rgb") {
            return nsColor(fromRGBFunction: trimmed)
        }
        var cleaned = trimmed.uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        switch cleaned.count {
        case 3:
            // Expand #RGB → #RRGGBB
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
            fallthrough
        case 6:
            guard let value = UInt64(cleaned, radix: 16) else { return nil }
            let r = CGFloat((value >> 16) & 0xFF) / 255
            let g = CGFloat((value >> 8) & 0xFF) / 255
            let b = CGFloat(value & 0xFF) / 255
            return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
        case 8:
            guard let value = UInt64(cleaned, radix: 16) else { return nil }
            let r = CGFloat((value >> 24) & 0xFF) / 255
            let g = CGFloat((value >> 16) & 0xFF) / 255
            let b = CGFloat((value >> 8) & 0xFF) / 255
            let a = CGFloat(value & 0xFF) / 255
            return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    private static func nsColor(fromRGBFunction raw: String) -> NSColor? {
        let pattern =
            #"^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})(?:\s*,\s*(0|1|0?\.\d+|1\.0|\d{1,3}%))?\s*\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(
                in: raw,
                options: [],
                range: NSRange(raw.startIndex..<raw.endIndex, in: raw)
              ),
              match.numberOfRanges >= 4,
              let rRange = Range(match.range(at: 1), in: raw),
              let gRange = Range(match.range(at: 2), in: raw),
              let bRange = Range(match.range(at: 3), in: raw),
              let rInt = Int(raw[rRange]),
              let gInt = Int(raw[gRange]),
              let bInt = Int(raw[bRange]),
              (0...255).contains(rInt),
              (0...255).contains(gInt),
              (0...255).contains(bInt)
        else { return nil }

        var alpha: CGFloat = 1
        if match.numberOfRanges >= 5, let aRange = Range(match.range(at: 4), in: raw) {
            let aRaw = String(raw[aRange])
            if aRaw.hasSuffix("%"), let pct = Double(aRaw.dropLast()) {
                alpha = CGFloat(min(max(pct / 100, 0), 1))
            } else if let value = Double(aRaw) {
                alpha = CGFloat(min(max(value, 0), 1))
            }
        }
        return NSColor(
            calibratedRed: CGFloat(rInt) / 255,
            green: CGFloat(gInt) / 255,
            blue: CGFloat(bInt) / 255,
            alpha: alpha
        )
    }

    public static func hex(from color: NSColor) -> String {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

public extension ScreenshotItem {
    /// True when tags or notes include passwords, IBANs, cards, tokens, or OTPs.
    var isSensitive: Bool {
        ContentTagger.containsSensitive(tags) || ContentTagger.tag(text: notes).isSensitive
    }
}
