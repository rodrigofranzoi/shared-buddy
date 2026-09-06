import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Generates scannable QR code images from text payloads.
public enum QRCodeGenerator {
    /// Default pixel scale for a crisp, scannable bitmap (CIQR is 1px modules).
    public static let defaultScale: CGFloat = 12

    /// Builds an `NSImage` QR for `string`, or `nil` if encoding fails / input is empty.
    /// Always returns a bitmap-backed image so SwiftUI / pasteboard can render it reliably.
    public static func makeImage(from string: String, scale: CGFloat = defaultScale) -> NSImage? {
        guard let png = makePNGData(from: string, scale: scale),
              let image = NSImage(data: png) else { return nil }
        return image
    }

    /// PNG bytes suitable for pasteboard / file export.
    public static func makePNGData(from string: String, scale: CGFloat = defaultScale) -> Data? {
        guard let ciImage = makeCIImage(from: string, scale: scale) else { return nil }
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    private static func makeCIImage(from string: String, scale: CGFloat) -> CIImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmed.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let s = max(scale, 1)
        return output.transformed(by: CGAffineTransform(scaleX: s, y: s))
    }
}
