import XCTest
@testable import BuddyCore
import BuddyTesting
import BuddyLocalization

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

    func testImageKind() {
        let result = ContentTagger.tag(.image)
        XCTAssertEqual(result.tags, [.image])
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

    func testPresetDurations() {
        XCTAssertEqual(BuddyPausePreset.fiveMinutes.duration, 5 * 60)
        XCTAssertEqual(BuddyPausePreset.twoHours.duration, 2 * 60 * 60)
    }
}

final class BuddySealTests: XCTestCase {
    func testRoundTrip() throws {
        let payload = Data("secret-clipboard-value".utf8)
        let sealed = try BuddySeal.seal(payload)
        XCTAssertNotEqual(sealed, payload)
        let opened = try BuddySeal.open(sealed)
        XCTAssertEqual(opened, payload)
    }

    func testJSONRoundTrip() throws {
        let item = FavoriteShortcut(name: "x", content: "S3cret!Pass99")
        let sealed = try BuddySeal.sealJSON(item)
        let decoded = try BuddySeal.openJSON(sealed, as: FavoriteShortcut.self)
        XCTAssertEqual(decoded, item)
    }
}

final class BuddyDatabaseTests: XCTestCase {
    func testSealedPersistence() throws {
        let name = "BuddyDBTest-\(UUID().uuidString)"
        let db = try BuddyDatabase(appFolderName: name)
        let items = [
            ClipboardHistoryItem(text: "token abc", tags: [.apiKey], isSensitive: true)
        ]
        try db.saveSealedJSON(items, for: .clipboardItems)
        let loaded = try db.loadSealedJSON([ClipboardHistoryItem].self, for: .clipboardItems)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].text, "token abc")
        XCTAssertTrue(loaded[0].isSensitive)

        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: root.appendingPathComponent(name))
    }
}
