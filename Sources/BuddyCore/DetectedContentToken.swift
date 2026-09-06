import AppKit
import Foundation

/// A color or URL token extracted from OCR / selection / QR payload text.
public struct DetectedContentToken: Identifiable, Sendable, Equatable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case color
        case url
    }

    public let id: String
    public let raw: String
    public let kind: Kind

    public init(id: String, raw: String, kind: Kind) {
        self.id = id
        self.raw = raw
        self.kind = kind
    }

    public var openableURL: URL? {
        guard kind == .url else { return nil }
        return Self.openableURL(from: raw)
    }

    public var nsColor: NSColor? {
        guard kind == .color else { return nil }
        return EditorRedactionSettings.nsColor(fromColorToken: raw)
    }

    /// URL suitable for opening in a browser (http/https, or `www.` → https).
    public static func openableURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https", url.host != nil {
            return url
        }
        if trimmed.lowercased().hasPrefix("www."),
           let url = URL(string: "https://\(trimmed)"), url.host != nil {
            return url
        }
        return nil
    }
}

public enum DetectedContentExtractor {
    /// Max tokens returned from a blob (keeps Tools rail usable).
    public static let defaultLimit = 12

    private static let hexPattern = #"#(?:[A-Fa-f0-9]{8}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\b"#
    private static let rgbPattern =
        #"rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}(?:\s*,\s*(?:0|1|0?\.\d+|1\.0|\d{1,3}%))?\s*\)"#
    private static let urlPattern = #"(?:https?://|www\.)[^\s<>\"')\]]+"#

    /// Extracts embedded color and URL tokens from multi-line text (deduped, order preserved).
    public static func extractTokens(from text: String, limit: Int = defaultLimit) -> [DetectedContentToken] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }

        var seen = Set<String>()
        var ordered: [(String, DetectedContentToken.Kind)] = []

        func append(_ raw: String, kind: DetectedContentToken.Kind) {
            let key = raw.lowercased()
            guard seen.insert(key).inserted else { return }
            ordered.append((raw, kind))
        }

        // Whole-string shortcuts first (clipboard / QR payloads).
        if looksLikeColorToken(trimmed) {
            append(trimmed, kind: .color)
        } else if DetectedContentToken.openableURL(from: trimmed) != nil {
            append(trimmed, kind: .url)
        }

        collectMatches(in: trimmed, pattern: hexPattern) { match in
            guard EditorRedactionSettings.nsColor(fromColorToken: match) != nil else { return }
            append(match, kind: .color)
        }
        collectMatches(in: trimmed, pattern: rgbPattern) { match in
            guard EditorRedactionSettings.nsColor(fromColorToken: match) != nil else { return }
            append(match, kind: .color)
        }
        collectMatches(in: trimmed, pattern: urlPattern) { match in
            let cleaned = match.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)]}>\"'"))
            guard DetectedContentToken.openableURL(from: cleaned) != nil else { return }
            append(cleaned, kind: .url)
        }

        return ordered.prefix(limit).enumerated().map { index, pair in
            DetectedContentToken(
                id: "\(pair.1.rawValue)-\(index)-\(pair.0.lowercased())",
                raw: pair.0,
                kind: pair.1
            )
        }
    }

    /// True when the entire string is a hex or rgb(a) color token.
    public static func looksLikeColorToken(_ s: String) -> Bool {
        EditorRedactionSettings.nsColor(fromColorToken: s) != nil
    }

    private static func collectMatches(in text: String, pattern: String, body: (String) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, options: [], range: range) {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            body(String(text[swiftRange]))
        }
    }
}
