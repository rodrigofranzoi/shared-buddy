import Foundation
import AppKit
import Vision

/// Normalized (0–1, origin top-left) region of sensitive text found in an image.
public struct SensitiveImageRegion: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var tags: Set<ContentTag>
    public var text: String

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        tags: Set<ContentTag>,
        text: String = ""
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.tags = tags
        self.text = text
    }

    public func asBlurRedaction(padding: Double = 0.012) -> RedactionRect {
        let x = max(0, self.x - padding)
        let y = max(0, self.y - padding)
        let maxW = 1 - x
        let maxH = 1 - y
        let width = min(maxW, self.width + padding * 2)
        let height = min(maxH, self.height + padding * 2)
        return RedactionRect(
            x: x,
            y: y,
            width: width,
            height: height,
            style: .blur,
            blurRadius: EditorRedactionSettings.blurRadius
        )
    }
}

/// One piece of content that Auto-blur would redact.
public struct AutoBlurMatch: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var text: String
    public var tags: Set<ContentTag>
    public var region: SensitiveImageRegion

    public init(
        id: UUID = UUID(),
        text: String,
        tags: Set<ContentTag>,
        region: SensitiveImageRegion
    ) {
        self.id = id
        self.text = text
        self.tags = tags
        self.region = region
    }

    public var tagLabels: String {
        tags.map(ContentTagger.displayName(for:)).sorted().joined(separator: ", ")
    }
}

/// On-device OCR that locates passwords, IBANs, cards, tokens, and OTPs in screenshots.
public enum SensitiveRegionFinder {
    public static func findRegions(in imageData: Data) -> [SensitiveImageRegion] {
        guard let image = NSImage(data: imageData) else { return [] }
        return findRegions(in: image)
    }

    public static func findRegions(in image: NSImage) -> [SensitiveImageRegion] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        var regions: [SensitiveImageRegion] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let tagged = ContentTagger.tag(text: candidate.string)
            let embedded = ContentTagger.embeddedSensitiveTags(in: candidate.string)
            var tags = tagged.tags.intersection(ContentTagger.sensitiveTags)
            tags.formUnion(embedded)
            guard !tags.isEmpty else { continue }

            // Vision box: origin bottom-left → our redaction model: origin top-left.
            let box = observation.boundingBox
            regions.append(
                SensitiveImageRegion(
                    x: box.origin.x,
                    y: 1.0 - box.origin.y - box.height,
                    width: box.width,
                    height: box.height,
                    tags: tags,
                    text: candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        return regions
    }

    /// Preview of OCR / notes matches for the given tag selection.
    public static func autoBlurMatches(
        imageData: Data,
        notes: String,
        enabledTags: Set<ContentTag>
    ) -> [AutoBlurMatch] {
        let enabled = enabledTags.intersection(ContentTagger.sensitiveTags)
        guard !enabled.isEmpty else { return [] }

        var matches: [AutoBlurMatch] = []
        let ocrRegions = findRegions(in: imageData).filter { !$0.tags.isDisjoint(with: enabled) }
        for region in ocrRegions {
            let label = region.text.isEmpty
                ? "(detected \(region.tags.map(ContentTagger.displayName(for:)).sorted().joined(separator: ", ")))"
                : region.text
            matches.append(
                AutoBlurMatch(
                    text: label,
                    tags: region.tags.intersection(enabled),
                    region: region
                )
            )
        }

        let noteTags = ContentTagger.tag(text: notes).tags
            .union(ContentTagger.embeddedSensitiveTags(in: notes))
            .intersection(enabled)
        if !noteTags.isEmpty && ocrRegions.isEmpty {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackRegion = SensitiveImageRegion(
                x: 0.05,
                y: 0.05,
                width: 0.9,
                height: 0.12,
                tags: noteTags,
                text: trimmed
            )
            matches.append(
                AutoBlurMatch(
                    text: trimmed.isEmpty ? "(from notes)" : trimmed,
                    tags: noteTags,
                    region: fallbackRegion
                )
            )
        }
        return matches
    }

    /// Blur redactions for sensitive OCR hits, plus a fallback band when only notes are sensitive.
    public static func autoBlurRedactions(
        imageData: Data,
        notes: String,
        existing: [RedactionRect],
        enabledTags: Set<ContentTag>? = nil
    ) -> [RedactionRect] {
        let enabled = (enabledTags ?? SensitivePrivacySettings.autoBlurTags)
            .intersection(ContentTagger.sensitiveTags)
        guard !enabled.isEmpty else { return [] }

        let matches = autoBlurMatches(imageData: imageData, notes: notes, enabledTags: enabled)
        var additions: [RedactionRect] = []
        for match in matches {
            let rect = match.region.asBlurRedaction()
            if !existing.contains(where: { roughlyCovers($0, rect) })
                && !additions.contains(where: { roughlyCovers($0, rect) }) {
                additions.append(rect)
            }
        }
        return additions
    }

    public static func roughlyCovers(_ a: RedactionRect, _ b: RedactionRect) -> Bool {
        let ax2 = a.x + a.width
        let ay2 = a.y + a.height
        let bx2 = b.x + b.width
        let by2 = b.y + b.height
        let overlapX = max(0, min(ax2, bx2) - max(a.x, b.x))
        let overlapY = max(0, min(ay2, by2) - max(a.y, b.y))
        let overlap = overlapX * overlapY
        let bArea = max(b.width * b.height, 0.0001)
        return overlap / bArea >= 0.6
    }
}
