import Foundation
import BuddyCore

public enum BuddyFixtures {
    public static let otpEmail = """
    From: security@example.com
    Subject: Your verification code

    Use verification code 482913 to sign in. This one-time passcode expires in 10 minutes.
    """

    public static let otpEmailWeak = """
    Hello, your order 123456 shipped today.
    """

    public static let sampleURL = "https://example.com/path"
    public static let sampleBearer = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0In0.signature"
    public static let sampleIBAN = "DE89 3704 0044 0532 0130 00"
    public static let sampleSHA = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    public static let samplePassword = "S3cret!Pass99"
    public static let sampleColor = "#1A73E8"

    public static func taggedSamples() -> [(String, Set<ContentTag>)] {
        [
            (sampleURL, [.url]),
            (sampleIBAN, [.iban]),
            (sampleSHA, [.sha]),
            (sampleColor, [.colorHex])
        ]
    }
}
