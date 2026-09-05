import XCTest
@testable import BuddyCore
import BuddyTesting
import BuddyLocalization

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
