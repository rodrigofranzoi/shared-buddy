import XCTest
@testable import BuddyCore
import BuddyTesting
import BuddyLocalization
import AppKit
import AppKit
import CoreImage
import Vision

final class ContentSafetyTests: XCTestCase {
    func testBlocksPornographyKeywords() {
        XCTAssertTrue(ContentSafety.evaluate(text: "Check this pornhub link").isBlocked)
        XCTAssertTrue(ContentSafety.evaluate(text: "free porn video tonight").isBlocked)
        XCTAssertTrue(ContentSafety.evaluate(text: "https://www.onlyfans.com/u").isBlocked)
        XCTAssertTrue(ContentSafety.evaluate(text: "NSFW gallery").isBlocked)
    }

    func testAllowsViolentExplicitLanguage() {
        XCTAssertFalse(ContentSafety.evaluate(text: "That bloody massacre was fucking brutal").isBlocked)
        XCTAssertFalse(ContentSafety.evaluate(text: "Kill the process and damn the bullets").isBlocked)
        XCTAssertFalse(ContentSafety.evaluate(text: "Gunshot wound report from the hospital").isBlocked)
        XCTAssertFalse(ContentSafety.evaluate(text: "What an asshole move in that fight").isBlocked)
    }

    func testAllowsInnocentText() {
        XCTAssertFalse(ContentSafety.evaluate(text: BuddyFixtures.sampleURL).isBlocked)
        XCTAssertFalse(ContentSafety.evaluate(text: "Meeting notes for Sussex project").isBlocked)
        XCTAssertFalse(ContentSafety.evaluate(text: "Canal path analysis").isBlocked)
    }
}

final class ContentTaggerTests: XCTestCase {
    func testURL() {
        let result = ContentTagger.tag(text: BuddyFixtures.sampleURL)
        XCTAssertTrue(result.tags.contains(.url))
    }

    func testIBANSensitive() {
        let result = ContentTagger.tag(text: BuddyFixtures.sampleIBAN)
        XCTAssertTrue(result.tags.contains(.iban))
        XCTAssertTrue(result.isSensitive)
    }

    func testSHA() {
        let result = ContentTagger.tag(text: BuddyFixtures.sampleSHA)
        XCTAssertTrue(result.tags.contains(.sha))
    }

    func testPassword() {
        let result = ContentTagger.tag(text: BuddyFixtures.samplePassword)
        XCTAssertTrue(result.tags.contains(.password))
        XCTAssertTrue(result.isSensitive)
    }

    func testBearer() {
        let result = ContentTagger.tag(text: BuddyFixtures.sampleBearer)
        XCTAssertTrue(result.tags.contains(.bearerToken))
    }

    func testColor() {
        let result = ContentTagger.tag(text: BuddyFixtures.sampleColor)
        XCTAssertTrue(result.tags.contains(.colorHex))
    }

    func testRGBColorTag() {
        let result = ContentTagger.tag(text: "rgb(26, 115, 232)")
        XCTAssertTrue(result.tags.contains(.colorHex))
    }

    func testRGBAColorTag() {
        let result = ContentTagger.tag(text: "rgba(26, 115, 232, 0.5)")
        XCTAssertTrue(result.tags.contains(.colorHex))
    }

    func testImageKind() {
        let result = ContentTagger.tag(.image)
        XCTAssertEqual(result.tags, [.image])
    }
}

final class DetectedContentExtractorTests: XCTestCase {
    func testHex3() {
        let tokens = DetectedContentExtractor.extractTokens(from: "#1A7")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .color)
        XCTAssertNotNil(tokens[0].nsColor)
    }

    func testHex6() {
        let tokens = DetectedContentExtractor.extractTokens(from: "#1A73E8")
        XCTAssertEqual(tokens.map(\.raw), ["#1A73E8"])
        XCTAssertEqual(tokens[0].kind, .color)
    }

    func testHex8() {
        let tokens = DetectedContentExtractor.extractTokens(from: "#1A73E880")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .color)
        let color = tokens[0].nsColor
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.alphaComponent ?? 0, 128.0 / 255.0, accuracy: 0.01)
    }

    func testRGB() {
        let tokens = DetectedContentExtractor.extractTokens(from: "rgb(26, 115, 232)")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .color)
        let color = tokens[0].nsColor
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.redComponent ?? 0, 26.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(color?.greenComponent ?? 0, 115.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(color?.blueComponent ?? 0, 232.0 / 255.0, accuracy: 0.01)
    }

    func testRGBA() {
        let tokens = DetectedContentExtractor.extractTokens(from: "rgba(10, 20, 30, 0.25)")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].nsColor?.alphaComponent ?? 0, 0.25, accuracy: 0.01)
    }

    func testMixedOCRExtractsColorAndURL() {
        let blob = """
        Brand primary #1A73E8
        Docs: https://example.com/guide
        Also rgb(255, 0, 128)
        """
        let tokens = DetectedContentExtractor.extractTokens(from: blob)
        let kinds = tokens.map(\.kind)
        XCTAssertTrue(kinds.contains(.color))
        XCTAssertTrue(kinds.contains(.url))
        XCTAssertTrue(tokens.contains(where: { $0.raw == "#1A73E8" }))
        XCTAssertTrue(tokens.contains(where: { $0.raw.lowercased().contains("example.com") }))
        XCTAssertTrue(tokens.contains(where: { $0.raw.lowercased().hasPrefix("rgb(") }))
        XCTAssertNotNil(tokens.first(where: { $0.kind == .url })?.openableURL)
    }

    func testIgnoresNonColorText() {
        let tokens = DetectedContentExtractor.extractTokens(from: "Meeting notes for Sussex project")
        XCTAssertTrue(tokens.isEmpty)
    }

    func testInvalidRGBIgnored() {
        XCTAssertFalse(DetectedContentExtractor.looksLikeColorToken("rgb(999, 0, 0)"))
        let color = EditorRedactionSettings.nsColor(fromColorToken: "rgb(999, 0, 0)")
        XCTAssertNil(color)
    }

    func testDedupesAndLimits() {
        let blob = Array(repeating: "#FFFFFF https://a.com", count: 20).joined(separator: "\n")
        let tokens = DetectedContentExtractor.extractTokens(from: blob, limit: 5)
        XCTAssertLessThanOrEqual(tokens.count, 5)
        let keys = Set(tokens.map { $0.raw.lowercased() })
        XCTAssertEqual(keys.count, tokens.count)
    }

    func testClipboardItemListHelpers() {
        let colorItem = ClipboardHistoryItem(text: "#1A73E8", tags: [.colorHex])
        XCTAssertNotNil(colorItem.listColor)
        XCTAssertNil(colorItem.listOpenableURL)

        let urlItem = ClipboardHistoryItem(text: "https://example.com/x", tags: [.url])
        XCTAssertNotNil(urlItem.listOpenableURL)
        XCTAssertNil(urlItem.listColor)

        let imageItem = ClipboardHistoryItem(imageData: Data([0]), tags: [.image])
        XCTAssertNil(imageItem.listColor)
    }

    func testOcrTextDecodesMissingKeyAsEmpty() throws {
        let clipboard = ClipboardHistoryItem(text: "hello", tags: [.text])
        var clipboardJSON = try JSONEncoder().encode(clipboard)
        var clipboardObject = try JSONSerialization.jsonObject(with: clipboardJSON) as! [String: Any]
        clipboardObject.removeValue(forKey: "ocrText")
        clipboardJSON = try JSONSerialization.data(withJSONObject: clipboardObject)
        let decodedClipboard = try JSONDecoder().decode(ClipboardHistoryItem.self, from: clipboardJSON)
        XCTAssertEqual(decodedClipboard.ocrText, "")

        let shot = ScreenshotItem(imageData: Data([1, 2, 3]), title: "Shot", notes: "memo", ocrText: "visible")
        var shotJSON = try JSONEncoder().encode(shot)
        var shotObject = try JSONSerialization.jsonObject(with: shotJSON) as! [String: Any]
        shotObject.removeValue(forKey: "ocrText")
        shotJSON = try JSONSerialization.data(withJSONObject: shotObject)
        let decodedShot = try JSONDecoder().decode(ScreenshotItem.self, from: shotJSON)
        XCTAssertEqual(decodedShot.ocrText, "")
        XCTAssertEqual(decodedShot.notes, "memo")
    }
}

final class OTPDetectorTests: XCTestCase {
    func testExtractsCodeFromVerificationEmail() {
        let match = OTPDetector.extract(from: BuddyFixtures.otpEmail)
        XCTAssertEqual(match?.code, "482913")
    }

    func testIgnoresOrderNumberWithoutHints() {
        let match = OTPDetector.extract(from: BuddyFixtures.otpEmailWeak)
        XCTAssertNil(match)
    }
}

final class LocaleTests: XCTestCase {
    func testTenLocales() {
        XCTAssertEqual(BuddyLocale.supported.count, 10)
        XCTAssertTrue(BuddyLocale.ar.isRTL)
        XCTAssertFalse(BuddyLocale.en.isRTL)
    }
}

final class EphemeralCacheTests: XCTestCase {
    func testTTL() {
        let cache = EphemeralOTPCache()
        cache.store("123456", ttl: 60)
        XCTAssertEqual(cache.current(), "123456")
        cache.clear()
        XCTAssertNil(cache.current())
    }
}

@MainActor
final class BuddyPauseControllerTests: XCTestCase {
    func testSessionPauseDoesNotPersist() {
        let defaults = UserDefaults(suiteName: "buddy.pause.tests.session")!
        defaults.removePersistentDomain(forName: "buddy.pause.tests.session")
        let pause = BuddyPauseController(defaults: defaults)
        pause.pauseUntilNextSession()
        XCTAssertTrue(pause.isPaused)
        XCTAssertTrue(pause.isUntilNextSession)
        XCTAssertEqual(defaults.double(forKey: BuddySettingsKey.pauseUntil), 0, accuracy: 0.001)

        let restored = BuddyPauseController(defaults: defaults)
        restored.restorePersistedPauseIfNeeded()
        XCTAssertFalse(restored.isPaused)
    }

    func testTimedPausePersistsAndResumes() {
        let defaults = UserDefaults(suiteName: "buddy.pause.tests.timed")!
        defaults.removePersistentDomain(forName: "buddy.pause.tests.timed")
        let pause = BuddyPauseController(defaults: defaults)
        pause.pause(for: 3600)
        XCTAssertTrue(pause.isPaused)
        XCTAssertFalse(pause.isUntilNextSession)
        XCTAssertGreaterThan(defaults.double(forKey: BuddySettingsKey.pauseUntil), 0)

        pause.resume()
        XCTAssertFalse(pause.isPaused)
        XCTAssertEqual(defaults.double(forKey: BuddySettingsKey.pauseUntil), 0, accuracy: 0.001)
    }

    func testPermanentPausePersistsAcrossRestore() {
        let defaults = UserDefaults(suiteName: "buddy.pause.tests.permanent")!
        defaults.removePersistentDomain(forName: "buddy.pause.tests.permanent")
        let pause = BuddyPauseController(defaults: defaults)
        pause.pausePermanently()
        XCTAssertTrue(pause.isPaused)
        XCTAssertTrue(pause.isPermanent)
        XCTAssertTrue(defaults.bool(forKey: BuddySettingsKey.pausePermanently))

        let restored = BuddyPauseController(defaults: defaults)
        restored.restorePersistedPauseIfNeeded()
        XCTAssertTrue(restored.isPaused)
        XCTAssertTrue(restored.isPermanent)

        restored.resume()
        XCTAssertFalse(restored.isPaused)
        XCTAssertFalse(defaults.bool(forKey: BuddySettingsKey.pausePermanently))
    }

    func testPresetDurations() {
        XCTAssertEqual(BuddyPausePreset.fiveMinutes.duration, 5 * 60)
        XCTAssertEqual(BuddyPausePreset.twoHours.duration, 2 * 60 * 60)
    }
}

final class QRCodeGeneratorTests: XCTestCase {
    func testGeneratesPNGForText() {
        let data = QRCodeGenerator.makePNGData(from: "https://example.com/buddy")
        XCTAssertNotNil(data)
        XCTAssertFalse(data!.isEmpty)
        XCTAssertNotNil(NSImage(data: data!))
    }

    func testRejectsEmptyPayload() {
        XCTAssertNil(QRCodeGenerator.makeImage(from: "   "))
        XCTAssertNil(QRCodeGenerator.makePNGData(from: ""))
    }

    func testRoundTripDetect() {
        guard let png = QRCodeGenerator.makePNGData(from: "buddy-qr-payload") else {
            return XCTFail("expected PNG")
        }
        let payloads = ScreenshotSmartTools.detectQRCodes(in: png)
        XCTAssertEqual(payloads.map(\.content), ["buddy-qr-payload"])
    }
}


final class SensitiveRegionFinderTests: XCTestCase {
    func testAutoBlurFallbackFromNotes() {
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 20).fill()
        image.unlockFocus()
        let data = image.tiffRepresentation!
        let rects = SensitiveRegionFinder.autoBlurRedactions(
            imageData: data,
            notes: BuddyFixtures.sampleIBAN,
            existing: []
        )
        XCTAssertFalse(rects.isEmpty)
        XCTAssertEqual(rects.first?.style, .blur)
    }
}

final class QRCodePayloadTests: XCTestCase {
    func testClassifiesLinkAndText() {
        XCTAssertEqual(QRCodePayload.kind(for: "https://example.com/path"), .link)
        XCTAssertEqual(QRCodePayload.kind(for: "www.example.com"), .link)
        XCTAssertEqual(QRCodePayload.kind(for: "Meeting notes for Sussex"), .text)
        XCTAssertEqual(QRCodePayload.kind(for: "WIFI:T:WPA;S:Home;P:secret;;"), .text)
    }

    func testOpenableURL() {
        let https = QRCodePayload(id: 0, content: "https://example.com", kind: .link)
        XCTAssertEqual(https.openableURL?.absoluteString, "https://example.com")

        let www = QRCodePayload(id: 1, content: "www.example.com", kind: .link)
        XCTAssertEqual(www.openableURL?.absoluteString, "https://www.example.com")

        let text = QRCodePayload(id: 2, content: "plain text", kind: .text)
        XCTAssertNil(text.openableURL)
    }

    func testDetectsMultipleQRCodesWithMixedKinds() throws {
        let link = "https://example.com/qr-test"
        let text = "hello-from-qr"
        let imageData = try Self.compositePNG(
            payloads: [link, text],
            cellSize: 8
        )
        let found = ScreenshotSmartTools.detectQRCodes(in: imageData)
        XCTAssertEqual(found.count, 2)
        let contents = Set(found.map(\.content))
        XCTAssertEqual(contents, Set([link, text]))
        XCTAssertEqual(found.first(where: { $0.content == link })?.kind, .link)
        XCTAssertEqual(found.first(where: { $0.content == text })?.kind, .text)
    }

    func testDetectsQRFromTIFFScreenshotStyleData() throws {
        let payload = "https://example.com/tiff-qr"
        let imageData = try Self.compositePNG(payloads: [payload], cellSize: 8)
        // Round-trip through TIFF the way ScreenshotStore persists captures.
        let image = NSImage(data: imageData)!
        let tiff = image.tiffRepresentation!
        let found = ScreenshotSmartTools.detectQRCodes(in: tiff)
        XCTAssertEqual(found.map(\.content), [payload])
    }

    private static func compositePNG(payloads: [String], cellSize: Int) throws -> Data {
        let tiles: [NSImage] = try payloads.map { try qrImage(payload: $0, cellSize: cellSize) }
        let tileSize = tiles[0].size
        let gap: CGFloat = 24
        let width = tileSize.width * CGFloat(tiles.count) + gap * CGFloat(max(tiles.count - 1, 0)) + 40
        let height = tileSize.height + 40
        let canvas = NSImage(size: NSSize(width: width, height: height))
        canvas.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvas.size).fill()
        for (index, tile) in tiles.enumerated() {
            let x = 20 + CGFloat(index) * (tileSize.width + gap)
            tile.draw(in: NSRect(x: x, y: 20, width: tileSize.width, height: tileSize.height))
        }
        canvas.unlockFocus()
        guard let tiff = canvas.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "QRCodePayloadTests", code: 1)
        }
        return png
    }

    private static func qrImage(payload: String, cellSize: Int) throws -> NSImage {
        let data = Data(payload.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw NSError(domain: "QRCodePayloadTests", code: 2)
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else {
            throw NSError(domain: "QRCodePayloadTests", code: 3)
        }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: CGFloat(cellSize), y: CGFloat(cellSize)))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
