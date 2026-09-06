import AppKit
import Foundation
import Vision

/// A line of OCR text in normalized image coordinates (origin top-left).
public struct RecognizedTextLine: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(text: String, x: Double, y: Double, width: Double, height: Double) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Full-image OCR for selecting and copying text from screenshots.
public enum ScreenshotOCR {
    public static func recognizeLines(in imageData: Data) -> [RecognizedTextLine] {
        guard let image = NSImage(data: imageData) else { return [] }
        return recognizeLines(in: image)
    }

    /// Joined OCR text suitable for search indexing and copy-all.
    public static func recognizedText(in imageData: Data) -> String {
        recognizeLines(in: imageData).map(\.text).joined(separator: "\n")
    }

    public static func recognizeLines(in image: NSImage) -> [RecognizedTextLine] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        var lines: [RecognizedTextLine] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let box = observation.boundingBox
            lines.append(
                RecognizedTextLine(
                    text: trimmed,
                    x: box.origin.x,
                    y: 1.0 - box.origin.y - box.height,
                    width: box.width,
                    height: box.height
                )
            )
        }

        // Reading order: top-to-bottom, then left-to-right.
        return lines.sorted {
            if abs($0.y - $1.y) > 0.015 { return $0.y < $1.y }
            return $0.x < $1.x
        }
    }

    /// Text whose OCR boxes intersect the normalized selection (top-left origin).
    public static func text(
        in selection: CGRect,
        from lines: [RecognizedTextLine],
        minimumOverlap: CGFloat = 0.2
    ) -> String {
        guard selection.width > 0, selection.height > 0 else { return "" }
        let hits = lines.filter { line in
            let overlap = selection.intersection(line.rect)
            guard !overlap.isNull, !overlap.isEmpty else { return false }
            let area = line.rect.width * line.rect.height
            guard area > 0 else { return false }
            return (overlap.width * overlap.height) / area >= minimumOverlap
        }
        return hits.map(\.text).joined(separator: "\n")
    }
}
