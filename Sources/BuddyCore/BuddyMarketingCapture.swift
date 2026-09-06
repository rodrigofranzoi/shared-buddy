import AppKit
import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

public extension Notification.Name {
    static let buddyMarketingStageScene = Notification.Name("buddy.marketing.stageScene")
}

/// Launch-arg driven store screenshot capture for App Store assets.
///
/// Usage:
/// ```
/// App.app --args -BuddyMarketingCapture \
///   -BuddyCaptureOut /path/to/docs/screenshots/en/raw \
///   -AppleLanguages '(en)'
/// ```
@MainActor
public enum BuddyMarketingCapture {
    public static let argument = "-BuddyMarketingCapture"
    public static let outArgument = "-BuddyCaptureOut"
    public static let sceneKey = "scene"

    public static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    public static var outputDirectory: URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: outArgument), args.indices.contains(idx + 1) else {
            return nil
        }
        return URL(fileURLWithPath: (args[idx + 1] as NSString).expandingTildeInPath, isDirectory: true)
    }

    public static func stage(_ scene: String) {
        NotificationCenter.default.post(
            name: .buddyMarketingStageScene,
            object: nil,
            userInfo: [sceneKey: scene]
        )
    }

    public static func ensureOutputDirectory() throws -> URL {
        guard let url = outputDirectory else {
            throw CaptureError.missingOutputDirectory
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func captureWindow(_ window: NSWindow, to url: URL) throws {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))

        let windowID = CGWindowID(window.windowNumber)

        // Prefer screencapture (handles retina + permissions more reliably).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-l", String(windowID), "-o", "-x", url.path]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0,
               FileManager.default.fileExists(atPath: url.path),
               (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 > 10_000 {
                return
            }
        } catch {
            // Fall through to CGWindowList.
        }

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw CaptureError.captureFailed(windowID)
        }
        try writePNG(cgImage, to: url)
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        guard let dest else { throw CaptureError.writeFailed }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CaptureError.writeFailed }
    }

    public static func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    public enum CaptureError: Error, LocalizedError {
        case missingOutputDirectory
        case captureFailed(CGWindowID)
        case writeFailed
        case missingMainWindow
        case missingPopoverWindow

        public var errorDescription: String? {
            switch self {
            case .missingOutputDirectory: return "Missing -BuddyCaptureOut path"
            case .captureFailed(let id): return "Failed to capture window \(id)"
            case .writeFailed: return "Failed to write PNG"
            case .missingMainWindow: return "Main window not found"
            case .missingPopoverWindow: return "Popover window not found"
            }
        }
    }
}

// MARK: - Fixture images for marketing seed data

public enum BuddyMarketingFixtures {
    private static let ciContext = CIContext(options: nil)

    public static func pngData(_ image: NSImage) -> Data {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return data
    }

    public static func loginForm(size: CGSize = CGSize(width: 900, height: 560)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()

        let card = NSRect(x: 220, y: 90, width: 460, height: 360)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: card, xRadius: 16, yRadius: 16).fill()
        NSColor(calibratedWhite: 0.85, alpha: 1).setStroke()
        NSBezierPath(roundedRect: card, xRadius: 16, yRadius: 16).stroke()

        drawText("Sign in", at: CGPoint(x: 250, y: 390), size: 28, bold: true)
        drawText("Email", at: CGPoint(x: 250, y: 330), size: 13, color: .secondaryLabelColor)
        drawField(NSRect(x: 250, y: 290, width: 400, height: 34), text: "you@company.com")
        drawText("Password", at: CGPoint(x: 250, y: 250), size: 13, color: .secondaryLabelColor)
        drawField(NSRect(x: 250, y: 210, width: 400, height: 34), text: "SecretPass123!")
        drawText("IBAN NL91 ABNA 0417 1643 00", at: CGPoint(x: 250, y: 160), size: 13, color: .secondaryLabelColor)
        drawButton(NSRect(x: 250, y: 110, width: 400, height: 40), title: "Continue")
        image.unlockFocus()
        return pngData(image)
    }

    public static func dashboard(size: CGSize = CGSize(width: 960, height: 600)) -> Data {
        if let charts = bundledPNG("demo-dashboard-charts") {
            return charts
        }
        // Prefer payslip fixture when charts asset is absent.
        if let payslip = bundledPNG("demo-payslip") {
            return payslip
        }
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        drawText("Weekly revenue", at: CGPoint(x: 40, y: 540), size: 24, bold: true)
        drawText("Dashboard chart", at: CGPoint(x: 40, y: 510), size: 13, color: .secondaryLabelColor)

        let chart = NSRect(x: 40, y: 80, width: 880, height: 400)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: chart, xRadius: 12, yRadius: 12).fill()

        let accent = NSColor(calibratedRed: 1, green: 0.48, blue: 0.24, alpha: 1)
        accent.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 4
        path.move(to: CGPoint(x: 80, y: 160))
        path.line(to: CGPoint(x: 220, y: 260))
        path.line(to: CGPoint(x: 360, y: 220))
        path.line(to: CGPoint(x: 520, y: 340))
        path.line(to: CGPoint(x: 700, y: 300))
        path.line(to: CGPoint(x: 860, y: 420))
        path.stroke()
        image.unlockFocus()
        return pngData(image)
    }

    /// Demo payslip used for Quick edit marketing captures.
    public static func payslip() -> Data {
        if let data = bundledPNG("demo-payslip") {
            return data
        }
        return dashboard()
    }

    private static func bundledPNG(_ name: String) -> Data? {
        let url =
            Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Marketing")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        guard let url, let data = try? Data(contentsOf: url), !data.isEmpty else {
            return nil
        }
        return data
    }

    public static func invoice(size: CGSize = CGSize(width: 800, height: 1000)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        drawText("Invoice #4821", at: CGPoint(x: 48, y: 930), size: 28, bold: true)
        drawText("Amount due: EUR 1,240.00", at: CGPoint(x: 48, y: 880), size: 16)
        drawText("IBAN: DE89 3704 0044 0532 0130 00", at: CGPoint(x: 48, y: 840), size: 14)
        drawText("Card: 4111 1111 1111 1111", at: CGPoint(x: 48, y: 810), size: 14)
        drawText("Thank you for your business.", at: CGPoint(x: 48, y: 740), size: 14, color: .secondaryLabelColor)
        image.unlockFocus()
        return pngData(image)
    }

    public static func inviteWithQR(size: CGSize = CGSize(width: 720, height: 720)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 1, green: 0.95, blue: 0.9, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        drawText("Join Buddy Office", at: CGPoint(x: 48, y: 640), size: 28, bold: true)
        drawText("Scan to open invite", at: CGPoint(x: 48, y: 600), size: 14, color: .secondaryLabelColor)
        if let qr = qrImage(payload: "https://buddy.app/invite", dimension: 360) {
            qr.draw(in: NSRect(x: 180, y: 160, width: 360, height: 360))
        }
        image.unlockFocus()
        return pngData(image)
    }

    public static func brandPalette(size: CGSize = CGSize(width: 800, height: 500)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        drawText("Brand palette", at: CGPoint(x: 40, y: 430), size: 24, bold: true)
        let swatches: [(NSColor, String)] = [
            (NSColor(calibratedRed: 0.91, green: 0.36, blue: 0.13, alpha: 1), "#E85D22"),
            (NSColor(calibratedRed: 0.06, green: 0.73, blue: 0.51, alpha: 1), "#10B981"),
            (NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1), "#3B82F6")
        ]
        for (i, pair) in swatches.enumerated() {
            let x = 40 + CGFloat(i) * 240
            pair.0.setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: 140, width: 200, height: 240), xRadius: 16, yRadius: 16).fill()
            drawText(pair.1, at: CGPoint(x: x + 40, y: 90), size: 16, bold: true)
        }
        image.unlockFocus()
        return pngData(image)
    }

    public static func meetingNotes(size: CGSize = CGSize(width: 700, height: 500)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        drawText("Meeting notes", at: CGPoint(x: 40, y: 430), size: 24, bold: true)
        drawText("• Ship gallery blur unlock", at: CGPoint(x: 40, y: 360), size: 16)
        drawText("• Polish OCR copy flow", at: CGPoint(x: 40, y: 320), size: 16)
        drawText("• Prep App Store screenshots", at: CGPoint(x: 40, y: 280), size: 16)
        image.unlockFocus()
        return pngData(image)
    }

    public static func tinySwatch(hex: String = "#10B981", size: CGSize = CGSize(width: 120, height: 120)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        (NSColor(calibratedRed: 0.06, green: 0.73, blue: 0.51, alpha: 1)).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return pngData(image)
    }

    private static func qrImage(payload: String, dimension: CGFloat) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = dimension / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: dimension, height: dimension))
    }

    private static func drawText(
        _ string: String,
        at point: CGPoint,
        size: CGFloat,
        bold: Bool = false,
        color: NSColor = .labelColor
    ) {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        (string as NSString).draw(at: point, withAttributes: attrs)
    }

    private static func drawField(_ rect: NSRect, text: String) {
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        NSColor(calibratedWhite: 0.8, alpha: 1).setStroke()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).stroke()
        drawText(text, at: CGPoint(x: rect.minX + 12, y: rect.minY + 8), size: 14)
    }

    private static func drawButton(_ rect: NSRect, title: String) {
        NSColor(calibratedRed: 1, green: 0.48, blue: 0.24, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 15),
            .foregroundColor: NSColor.white
        ]
        let size = (title as NSString).size(withAttributes: attrs)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        (title as NSString).draw(at: origin, withAttributes: attrs)
    }
}
