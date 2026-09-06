import AppKit
import CoreImage
import Foundation
import Vision

/// A decoded QR / barcode payload with a simple content kind for UI actions.
public struct QRCodePayload: Identifiable, Sendable, Equatable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case link
        case text
    }

    public let id: Int
    public let content: String
    public let kind: Kind

    public init(id: Int, content: String, kind: Kind) {
        self.id = id
        self.content = content
        self.kind = kind
    }

    public var isLink: Bool { kind == .link }

    /// When the QR payload is itself a color token (`#RGB` / `rgb(...)`), expose it for swatch UI.
    public var colorToken: DetectedContentToken? {
        guard DetectedContentExtractor.looksLikeColorToken(content) else { return nil }
        return DetectedContentToken(id: "qr-color-\(id)", raw: content.trimmingCharacters(in: .whitespacesAndNewlines), kind: .color)
    }

    /// URL suitable for opening in a browser, if this payload is a link.
    public var openableURL: URL? {
        guard isLink else { return nil }
        let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https", url.host != nil {
            return url
        }
        if raw.lowercased().hasPrefix("www."),
           let url = URL(string: "https://\(raw)"), url.host != nil {
            return url
        }
        return nil
    }

    public static func kind(for content: String) -> Kind {
        ContentTagger.tag(text: content).tags.contains(.url) ? .link : .text
    }
}

public enum ScreenshotSmartTools {
    /// Decode QR / barcodes in image data. Returns every payload found (text, links, etc.).
    public static func detectQRCodes(in imageData: Data) -> [QRCodePayload] {
        guard let base = cgImage(from: imageData) else { return [] }

        var seen = Set<String>()
        var ordered: [String] = []

        func ingest(_ strings: [String]) {
            for raw in strings {
                let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty, seen.insert(content).inserted else { continue }
                ordered.append(content)
            }
        }

        // Passes ordered from cheapest → heavier enhancement for soft / framed / tiny screenshots.
        let candidates: [CGImage] = {
            var images: [CGImage] = [base]
            if let contrast = contrastBoost(base) { images.append(contrast) }
            if let cleaned = removeDecorativeFrame(base) {
                images.append(cleaned)
                images.append(padQuietZone(cleaned, relative: 0.2))
            }
            // Small captures need nearest-neighbor upscaling + quiet zone.
            let maxSide = max(base.width, base.height)
            if maxSide < 900 {
                let factor = max(3, Int(ceil(900.0 / Double(maxSide))))
                images.append(padQuietZone(upscale(base, factor: factor), relative: 0.15))
                if let cleaned = removeDecorativeFrame(base) {
                    images.append(padQuietZone(upscale(cleaned, factor: factor), relative: 0.2))
                }
                if let contrast = contrastBoost(base) {
                    images.append(padQuietZone(upscale(contrast, factor: factor), relative: 0.15))
                }
            } else {
                images.append(padQuietZone(base, relative: 0.08))
            }
            return images
        }()

        for image in candidates {
            ingest(visionPayloads(in: image))
            if !ordered.isEmpty { break }
            ingest(ciDetectorPayloads(in: image))
            if !ordered.isEmpty { break }
        }

        // Last resort: still merge CI + Vision across candidates if nothing unbroken yet.
        if ordered.isEmpty {
            for image in candidates {
                ingest(visionPayloads(in: image))
                ingest(ciDetectorPayloads(in: image))
            }
        }

        return ordered.enumerated().map { index, content in
            QRCodePayload(id: index, content: content, kind: QRCodePayload.kind(for: content))
        }
    }

    /// Sample a normalized top-left point (0…1) and return `#RRGGBB`, if possible.
    public static func sampleColorHex(in imageData: Data, atNormalized point: CGPoint) -> String? {
        guard let image = NSImage(data: imageData),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let px = min(max(Int(point.x * CGFloat(rep.pixelsWide)), 0), max(rep.pixelsWide - 1, 0))
        let py = min(max(Int(point.y * CGFloat(rep.pixelsHigh)), 0), max(rep.pixelsHigh - 1, 0))
        guard let color = rep.colorAt(x: px, y: py) else { return nil }
        return EditorRedactionSettings.hex(from: color)
    }

    // MARK: - Decoders

    private static func visionPayloads(in cgImage: CGImage) -> [String] {
        let revisions = [
            VNDetectBarcodesRequestRevision1,
            VNDetectBarcodesRequestRevision2,
            VNDetectBarcodesRequestRevision3,
            VNDetectBarcodesRequest.currentRevision
        ]
        var found: [String] = []
        var seen = Set<String>()
        for revision in revisions where VNDetectBarcodesRequest.supportedRevisions.contains(revision) {
            let request = VNDetectBarcodesRequest()
            request.revision = revision
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continue
            }
            for value in (request.results ?? []).compactMap(\.payloadStringValue) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, seen.insert(trimmed).inserted {
                    found.append(trimmed)
                }
            }
            if !found.isEmpty { break }
        }
        return found
    }

    private static func ciDetectorPayloads(in cgImage: CGImage) -> [String] {
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: CIImage(cgImage: cgImage)) as? [CIQRCodeFeature] ?? []
        return features.compactMap(\.messageString)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Image helpers

    private static func cgImage(from imageData: Data) -> CGImage? {
        if let source = CGImageSourceCreateWithData(imageData as CFData, nil),
           let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return cg
        }
        if let image = NSImage(data: imageData),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        guard let image = NSImage(data: imageData),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        if let cg = rep.cgImage { return cg }

        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        guard width > 0, height > 0 else { return nil }
        let canvas = NSImage(size: NSSize(width: width, height: height))
        canvas.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        canvas.unlockFocus()
        return canvas.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func upscale(_ cgImage: CGImage, factor: Int) -> CGImage {
        let factor = max(factor, 1)
        let width = cgImage.width * factor
        let height = cgImage.height * factor
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.interpolationQuality = .none
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage() ?? cgImage
    }

    private static func padQuietZone(_ cgImage: CGImage, relative: CGFloat) -> CGImage {
        let pad = max(16, Int(CGFloat(max(cgImage.width, cgImage.height)) * relative))
        let width = cgImage.width + pad * 2
        let height = cgImage.height + pad * 2
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.interpolationQuality = .none
        ctx.draw(cgImage, in: CGRect(x: pad, y: pad, width: cgImage.width, height: cgImage.height))
        return ctx.makeImage() ?? cgImage
    }

    private static func contrastBoost(_ cgImage: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: cgImage).applyingFilter(
            "CIColorControls",
            parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 2.4,
                kCIInputBrightnessKey: 0.02
            ]
        )
        return CIContext().createCGImage(ci, from: ci.extent)
    }

    /// Removes a dark decorative ring (common in rounded “QR card” screenshots) by
    /// flooding from the exterior and painting black pixels that touch it.
    private static func removeDecorativeFrame(_ cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 16, height > 16,
              let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: height * ctx.bytesPerRow)
        let bpr = ctx.bytesPerRow

        func isDark(_ x: Int, _ y: Int) -> Bool {
            let i = y * bpr + x * 4
            return Int(ptr[i]) + Int(ptr[i + 1]) + Int(ptr[i + 2]) < 300
        }

        var exterior = [Bool](repeating: false, count: width * height)
        var stack: [(Int, Int)] = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
        while let (x, y) = stack.popLast() {
            if x < 0 || y < 0 || x >= width || y >= height { continue }
            let p = y * width + x
            if exterior[p] || isDark(x, y) { continue }
            exterior[p] = true
            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        }

        var dist = [Int](repeating: -1, count: width * height)
        var queue: [(Int, Int)] = []
        for y in 0..<height {
            for x in 0..<width where isDark(x, y) {
                let right = x + 1 < width && exterior[y * width + (x + 1)]
                let left = x > 0 && exterior[y * width + (x - 1)]
                let down = y + 1 < height && exterior[(y + 1) * width + x]
                let up = y > 0 && exterior[(y - 1) * width + x]
                if right || left || down || up {
                    queue.append((x, y))
                    dist[y * width + x] = 0
                }
            }
        }

        let maxThickness = max(width, height) / 7
        var qi = 0
        while qi < queue.count {
            let (x, y) = queue[qi]
            qi += 1
            let d = dist[y * width + x]
            let i = y * bpr + x * 4
            ptr[i] = 255
            ptr[i + 1] = 255
            ptr[i + 2] = 255
            ptr[i + 3] = 255
            if d >= maxThickness { continue }
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                if nx < 0 || ny < 0 || nx >= width || ny >= height { continue }
                let np = ny * width + nx
                if dist[np] != -1 || !isDark(nx, ny) { continue }
                dist[np] = d + 1
                queue.append((nx, ny))
            }
        }

        return ctx.makeImage()
    }
}
