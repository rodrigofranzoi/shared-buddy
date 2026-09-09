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
    /// Max Paint Buddy color history items (newest first).
    public static let paintMaxHistoryCount = "buddy.paint.maxHistoryCount"
    /// How many recent colors appear in the Paint Buddy menu bar.
    public static let paintMenuBarRecentCount = "buddy.paint.menuBarRecentCount"
    /// When true, clipboard `#hex` colors are saved.
    public static let paintCaptureHex = "buddy.paint.captureHex"
    /// When true, clipboard `rgb(...)` colors are saved.
    public static let paintCaptureRGB = "buddy.paint.captureRGB"
    /// When true, clipboard `rgba(...)` colors are saved.
    public static let paintCaptureRGBA = "buddy.paint.captureRGBA"
    /// When true, named CSS colors (e.g. `red`) are saved.
    public static let paintCaptureNamed = "buddy.paint.captureNamed"
    /// When true, bare tuples like `(0,0,0)` / `0,0,0` are saved.
    public static let paintCaptureTuple = "buddy.paint.captureTuple"
    /// Preferred copy format: `hex` | `rgb` | `rgba`.
    public static let paintCopyFormat = "buddy.paint.copyFormat"
    /// Open the floating history panel when the app launches.
    public static let paintFloatingPanelOnLaunch = "buddy.paint.floatingPanelOnLaunch"
    /// Floating palette layout: `grid` | `minimal` | `detailed`.
    public static let paintFloatingViewMode = "buddy.paint.floatingViewMode"
    /// Swatch size (points) for Paint Buddy floating palette grid mode.
    public static let paintFloatingGridCellSize = "buddy.paint.floatingGridCellSize"
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

    /// Parses `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb(...)`, `rgba(...)`, named CSS colors,
    /// or bare tuples like `(0,0,0)` / `0, 0, 0`. Returns nil if invalid.
    public static func nsColor(fromColorToken token: String) -> NSColor? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("rgb") {
            return nsColor(fromRGBFunction: trimmed)
        }
        if let named = nsColor(fromNamedColor: lower) {
            return named
        }
        if let tuple = nsColor(fromTuple: trimmed) {
            return tuple
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
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        case 8:
            guard let value = UInt64(cleaned, radix: 16) else { return nil }
            let r = CGFloat((value >> 24) & 0xFF) / 255
            let g = CGFloat((value >> 16) & 0xFF) / 255
            let b = CGFloat((value >> 8) & 0xFF) / 255
            let a = CGFloat(value & 0xFF) / 255
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    /// Classifies a color token for Paint Buddy capture filters.
    public static func colorTokenKind(_ token: String) -> ColorTokenKind? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()

        if lower.hasPrefix("rgba(") {
            return nsColor(fromRGBFunction: trimmed) != nil ? .rgba : nil
        }
        if lower.hasPrefix("rgb(") {
            return nsColor(fromRGBFunction: trimmed) != nil ? .rgb : nil
        }
        if nsColor(fromNamedColor: lower) != nil {
            return .named
        }
        if nsColor(fromTuple: trimmed) != nil {
            return .tuple
        }

        var cleaned = trimmed
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard !cleaned.isEmpty,
              cleaned.unicodeScalars.allSatisfy({ hexChars.contains($0) }),
              [3, 6, 8].contains(cleaned.count),
              nsColor(fromColorToken: trimmed) != nil
        else { return nil }
        return .hex
    }

    private static func nsColor(fromNamedColor name: String) -> NSColor? {
        guard let rgb = cssNamedColors[name] else { return nil }
        return NSColor(
            srgbRed: CGFloat(rgb.0) / 255,
            green: CGFloat(rgb.1) / 255,
            blue: CGFloat(rgb.2) / 255,
            alpha: 1
        )
    }

    private static func nsColor(fromTuple raw: String) -> NSColor? {
        let pattern =
            #"^\(?\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})(?:\s*,\s*(0|1|0?\.\d+|1\.0|\d{1,3}%))?\s*\)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
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

        // Avoid treating bare hex-looking digits as tuples (handled earlier).
        // Require commas so "255" alone never matches.
        guard raw.contains(",") else { return nil }

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
            srgbRed: CGFloat(rInt) / 255,
            green: CGFloat(gInt) / 255,
            blue: CGFloat(bInt) / 255,
            alpha: alpha
        )
    }

    /// Common CSS Level 3 / X11 named colors (lowercase keys).
    private static let cssNamedColors: [String: (Int, Int, Int)] = [
        "aliceblue": (240, 248, 255), "antiquewhite": (250, 235, 215), "aqua": (0, 255, 255),
        "aquamarine": (127, 255, 212), "azure": (240, 255, 255), "beige": (245, 245, 220),
        "bisque": (255, 228, 196), "black": (0, 0, 0), "blanchedalmond": (255, 235, 205),
        "blue": (0, 0, 255), "blueviolet": (138, 43, 226), "brown": (165, 42, 42),
        "burlywood": (222, 184, 135), "cadetblue": (95, 158, 160), "chartreuse": (127, 255, 0),
        "chocolate": (210, 105, 30), "coral": (255, 127, 80), "cornflowerblue": (100, 149, 237),
        "cornsilk": (255, 248, 220), "crimson": (220, 20, 60), "cyan": (0, 255, 255),
        "darkblue": (0, 0, 139), "darkcyan": (0, 139, 139), "darkgoldenrod": (184, 134, 11),
        "darkgray": (169, 169, 169), "darkgreen": (0, 100, 0), "darkgrey": (169, 169, 169),
        "darkkhaki": (189, 183, 107), "darkmagenta": (139, 0, 139), "darkolivegreen": (85, 107, 47),
        "darkorange": (255, 140, 0), "darkorchid": (153, 50, 204), "darkred": (139, 0, 0),
        "darksalmon": (233, 150, 122), "darkseagreen": (143, 188, 143), "darkslateblue": (72, 61, 139),
        "darkslategray": (47, 79, 79), "darkslategrey": (47, 79, 79), "darkturquoise": (0, 206, 209),
        "darkviolet": (148, 0, 211), "deeppink": (255, 20, 147), "deepskyblue": (0, 191, 255),
        "dimgray": (105, 105, 105), "dimgrey": (105, 105, 105), "dodgerblue": (30, 144, 255),
        "firebrick": (178, 34, 34), "floralwhite": (255, 250, 240), "forestgreen": (34, 139, 34),
        "fuchsia": (255, 0, 255), "gainsboro": (220, 220, 220), "ghostwhite": (248, 248, 255),
        "gold": (255, 215, 0), "goldenrod": (218, 165, 32), "gray": (128, 128, 128),
        "green": (0, 128, 0), "greenyellow": (173, 255, 47), "grey": (128, 128, 128),
        "honeydew": (240, 255, 240), "hotpink": (255, 105, 180), "indianred": (205, 92, 92),
        "indigo": (75, 0, 130), "ivory": (255, 255, 240), "khaki": (240, 230, 140),
        "lavender": (230, 230, 250), "lavenderblush": (255, 240, 245), "lawngreen": (124, 252, 0),
        "lemonchiffon": (255, 250, 205), "lightblue": (173, 216, 230), "lightcoral": (240, 128, 128),
        "lightcyan": (224, 255, 255), "lightgoldenrodyellow": (250, 250, 210),
        "lightgray": (211, 211, 211), "lightgreen": (144, 238, 144), "lightgrey": (211, 211, 211),
        "lightpink": (255, 182, 193), "lightsalmon": (255, 160, 122), "lightseagreen": (32, 178, 170),
        "lightskyblue": (135, 206, 250), "lightslategray": (119, 136, 153),
        "lightslategrey": (119, 136, 153), "lightsteelblue": (176, 196, 222),
        "lightyellow": (255, 255, 224), "lime": (0, 255, 0), "limegreen": (50, 205, 50),
        "linen": (250, 240, 230), "magenta": (255, 0, 255), "maroon": (128, 0, 0),
        "mediumaquamarine": (102, 205, 170), "mediumblue": (0, 0, 205),
        "mediumorchid": (186, 85, 211), "mediumpurple": (147, 112, 219),
        "mediumseagreen": (60, 179, 113), "mediumslateblue": (123, 104, 238),
        "mediumspringgreen": (0, 250, 154), "mediumturquoise": (72, 209, 204),
        "mediumvioletred": (199, 21, 133), "midnightblue": (25, 25, 112),
        "mintcream": (245, 255, 250), "mistyrose": (255, 228, 225), "moccasin": (255, 228, 181),
        "navajowhite": (255, 222, 173), "navy": (0, 0, 128), "oldlace": (253, 245, 230),
        "olive": (128, 128, 0), "olivedrab": (107, 142, 35), "orange": (255, 165, 0),
        "orangered": (255, 69, 0), "orchid": (218, 112, 214), "palegoldenrod": (238, 232, 170),
        "palegreen": (152, 251, 152), "paleturquoise": (175, 238, 238),
        "palevioletred": (219, 112, 147), "papayawhip": (255, 239, 213),
        "peachpuff": (255, 218, 185), "peru": (205, 133, 63), "pink": (255, 192, 203),
        "plum": (221, 160, 221), "powderblue": (176, 224, 230), "purple": (128, 0, 128),
        "rebeccapurple": (102, 51, 153), "red": (255, 0, 0), "rosybrown": (188, 143, 143),
        "royalblue": (65, 105, 225), "saddlebrown": (139, 69, 19), "salmon": (250, 128, 114),
        "sandybrown": (244, 164, 96), "seagreen": (46, 139, 87), "seashell": (255, 245, 238),
        "sienna": (160, 82, 45), "silver": (192, 192, 192), "skyblue": (135, 206, 235),
        "slateblue": (106, 90, 205), "slategray": (112, 128, 144), "slategrey": (112, 128, 144),
        "snow": (255, 250, 250), "springgreen": (0, 255, 127), "steelblue": (70, 130, 180),
        "tan": (210, 180, 140), "teal": (0, 128, 128), "thistle": (216, 191, 216),
        "tomato": (255, 99, 71), "turquoise": (64, 224, 208), "violet": (238, 130, 238),
        "wheat": (245, 222, 179), "white": (255, 255, 255), "whitesmoke": (245, 245, 245),
        "yellow": (255, 255, 0), "yellowgreen": (154, 205, 50), "transparent": (0, 0, 0)
    ]

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
            srgbRed: CGFloat(rInt) / 255,
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

    /// Hex digits without a leading `#` (e.g. `1A73E8`).
    public static func hexPlain(from color: NSColor) -> String {
        let withHash = hex(from: color)
        return withHash.hasPrefix("#") ? String(withHash.dropFirst()) : withHash
    }

    /// Strips a leading `#` from a stored canonical hex string when present.
    public static func hexPlain(fromHex hex: String) -> String {
        hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    }

    public static func rgbString(from color: NSColor) -> String {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        return "rgb(\(r), \(g), \(b))"
    }

    public static func rgbaString(from color: NSColor) -> String {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        let a = converted.alphaComponent
        if abs(a - 1) < 0.000_1 {
            return "rgba(\(r), \(g), \(b), 1)"
        }
        let rounded = (a * 1000).rounded() / 1000
        return "rgba(\(r), \(g), \(b), \(rounded))"
    }

    /// 0–255 channel integers and alpha (0…1, up to 3 decimals) for per-channel copy.
    public static func rgbaComponents(from color: NSColor) -> (r: Int, g: Int, b: Int, a: Double) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        let a = converted.alphaComponent
        if abs(a - 1) < 0.000_1 {
            return (r, g, b, 1)
        }
        let rounded = (a * 1000).rounded() / 1000
        return (r, g, b, rounded)
    }
}

/// Kind of color token for Paint Buddy capture filters.
public enum ColorTokenKind: String, CaseIterable, Sendable, Codable {
    case hex
    case rgb
    case rgba
    case named
    case tuple
}

/// Preferred format when copying a color from Paint Buddy UI.
public enum PaintCopyFormat: String, CaseIterable, Sendable, Codable {
    case hex
    case hexPlain
    case rgb
    case rgba

    public func string(from color: NSColor) -> String {
        switch self {
        case .hex: return EditorRedactionSettings.hex(from: color)
        case .hexPlain: return EditorRedactionSettings.hexPlain(from: color)
        case .rgb: return EditorRedactionSettings.rgbString(from: color)
        case .rgba: return EditorRedactionSettings.rgbaString(from: color)
        }
    }

    /// Whether this preferred format is a hex family (with or without `#`).
    public var isHexFamily: Bool {
        switch self {
        case .hex, .hexPlain: return true
        case .rgb, .rgba: return false
        }
    }
}

/// Layout for Paint Buddy’s always-on-top floating palette.
public enum PaintFloatingViewMode: String, CaseIterable, Sendable, Codable {
    case grid
    case minimal
    case detailed
}

/// Persisted Paint Buddy capture / copy / history preferences.
public enum PaintColorSettings {
    public static let defaultMaxHistoryCount = 100
    public static let defaultMenuBarRecentCount = 12

    public static var maxHistoryCount: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.paintMaxHistoryCount) as? Int
                ?? defaultMaxHistoryCount,
            min: 10,
            max: 2000
        )
    }

    public static var menuBarRecentCount: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.paintMenuBarRecentCount) as? Int
                ?? defaultMenuBarRecentCount,
            min: 1,
            max: 50
        )
    }

    public static var captureHex: Bool {
        get { bool(for: BuddySettingsKey.paintCaptureHex, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.paintCaptureHex) }
    }

    public static var captureRGB: Bool {
        get { bool(for: BuddySettingsKey.paintCaptureRGB, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.paintCaptureRGB) }
    }

    public static var captureRGBA: Bool {
        get { bool(for: BuddySettingsKey.paintCaptureRGBA, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.paintCaptureRGBA) }
    }

    public static var captureNamed: Bool {
        get { bool(for: BuddySettingsKey.paintCaptureNamed, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.paintCaptureNamed) }
    }

    public static var captureTuple: Bool {
        get { bool(for: BuddySettingsKey.paintCaptureTuple, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.paintCaptureTuple) }
    }

    public static var copyFormat: PaintCopyFormat {
        get {
            let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.paintCopyFormat) ?? ""
            return PaintCopyFormat(rawValue: raw) ?? .hex
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: BuddySettingsKey.paintCopyFormat)
        }
    }

    public static var floatingPanelOnLaunch: Bool {
        get { bool(for: BuddySettingsKey.paintFloatingPanelOnLaunch, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.paintFloatingPanelOnLaunch) }
    }

    public static var floatingViewMode: PaintFloatingViewMode {
        get {
            let raw = UserDefaults.standard.string(forKey: BuddySettingsKey.paintFloatingViewMode) ?? ""
            return PaintFloatingViewMode(rawValue: raw) ?? .detailed
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: BuddySettingsKey.paintFloatingViewMode)
        }
    }

    public static let defaultFloatingGridCellSize = 72
    public static let minFloatingGridCellSize = 40
    public static let maxFloatingGridCellSize = 120

    public static var floatingGridCellSize: Int {
        clamped(
            UserDefaults.standard.object(forKey: BuddySettingsKey.paintFloatingGridCellSize) as? Int
                ?? defaultFloatingGridCellSize,
            min: minFloatingGridCellSize,
            max: maxFloatingGridCellSize
        )
    }

    public static func allows(_ kind: ColorTokenKind) -> Bool {
        switch kind {
        case .hex: return captureHex
        case .rgb: return captureRGB
        case .rgba: return captureRGBA
        case .named: return captureNamed
        case .tuple: return captureTuple
        }
    }

    private static func bool(for key: String, default defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func clamped(_ value: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(value, min), max)
    }
}

public extension ScreenshotItem {
    /// True when tags or notes include passwords, IBANs, cards, tokens, or OTPs.
    var isSensitive: Bool {
        ContentTagger.containsSensitive(tags) || ContentTagger.tag(text: notes).isSensitive
    }
}
