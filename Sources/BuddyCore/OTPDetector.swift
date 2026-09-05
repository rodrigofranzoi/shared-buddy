import Foundation

public struct OTPMatch: Sendable, Equatable {
    public let code: String
    public let confidence: Double

    public init(code: String, confidence: Double) {
        self.code = code
        self.confidence = confidence
    }
}

/// Conservative OTP extractor for email bodies and short messages.
public enum OTPDetector {
    private static let lexicalHints = [
        "verification code", "verification", "one-time", "one time", "otp",
        "passcode", "security code", "login code", "2fa", "two-factor",
        "código", "codigo", "code de", "codice", "verifizierung", "подтвержден"
    ]

    public static func extract(from text: String) -> OTPMatch? {
        let lower = text.lowercased()
        let hasLexical = lexicalHints.contains { lower.contains($0) }

        let patterns: [(String, Double)] = [
            (#"(?i)(?:code|otp|passcode|pin)[^\d]{0,20}(\d{4,8})"#, 0.85),
            (#"(?<![A-Za-z0-9])(\d{6})(?![A-Za-z0-9])"#, 0.55),
            (#"(?<![A-Za-z0-9])(\d{4})(?![A-Za-z0-9])"#, 0.35),
            (#"(?<![A-Za-z0-9])([A-Z0-9]{6,8})(?![A-Za-z0-9])"#, 0.4)
        ]

        var best: OTPMatch?

        for (pattern, base) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let codeRange = Range(match.range(at: 1), in: text) else { continue }
                let code = String(text[codeRange])
                if isLikelyFalsePositive(code, in: text) { continue }
                var score = base
                if hasLexical { score += 0.3 }
                if code.allSatisfy(\.isNumber), (code.count == 6 || code.count == 8) { score += 0.1 }
                if best == nil || score > best!.confidence {
                    best = OTPMatch(code: code, confidence: min(score, 1.0))
                }
            }
        }

        guard let best, best.confidence >= 0.65 || (hasLexical && best.confidence >= 0.5) else {
            return nil
        }
        return best
    }

    private static func isLikelyFalsePositive(_ code: String, in text: String) -> Bool {
        if code == "000000" || code == "123456" { return true }
        // Year-like
        if code.count == 4, let year = Int(code), (1990...2099).contains(year) { return true }
        // Phone fragments: long digit runs nearby
        if code.allSatisfy(\.isNumber), text.filter(\.isNumber).count > 12, !text.lowercased().contains("code") {
            return true
        }
        return false
    }
}
