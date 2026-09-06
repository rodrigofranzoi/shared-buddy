import Foundation

public enum ContentTag: String, Codable, CaseIterable, Sendable, Hashable {
    case url
    case email
    case phone
    case password
    case bearerToken
    case apiKey
    case sha
    case iban
    case creditCard
    case otp
    case amount
    case json
    case filePath
    case colorHex
    case image
    case text
    case file
    case richText
    case pdf
    case other
}

public struct TaggedContent: Sendable, Equatable {
    public let tags: Set<ContentTag>
    public let isSensitive: Bool

    public init(tags: Set<ContentTag>, isSensitive: Bool) {
        self.tags = tags
        self.isSensitive = isSensitive
    }
}

public enum ContentKind: Sendable, Equatable {
    case text(String)
    case image
}

public enum ContentTagger {
    /// Tags that can be marked sensitive (settings pickers + detection candidates).
    public static let sensitiveTags: Set<ContentTag> = [
        .password, .bearerToken, .apiKey, .iban, .creditCard, .otp,
        .email, .phone, .amount
    ]

    /// Whether any of `tags` is currently protected in Settings.
    public static func containsSensitive<S: Sequence>(_ tags: S) -> Bool where S.Element == ContentTag {
        !Set(tags).isDisjoint(with: SensitivePrivacySettings.protectedTags)
    }

    /// Short label for settings copy.
    public static let sensitiveTypesSummary =
        "passwords, IBANs, cards, API keys, OTPs, emails, phones, and amounts"

    /// Ordered list for sensitive-type settings UI.
    public static let autoBlurSelectableTags: [ContentTag] = [
        .password, .iban, .creditCard, .apiKey, .bearerToken, .otp, .email, .phone, .amount
    ]

    public static func displayName(for tag: ContentTag) -> String {
        switch tag {
        case .password: return "Passwords"
        case .iban: return "IBANs"
        case .creditCard: return "Cards"
        case .apiKey: return "API keys"
        case .bearerToken: return "Tokens"
        case .otp: return "OTPs"
        case .url: return "URLs"
        case .email: return "Emails"
        case .phone: return "Phones"
        case .amount: return "Amounts"
        case .sha: return "Hashes"
        case .json: return "JSON"
        case .filePath: return "Paths"
        case .colorHex: return "Colors"
        case .image: return "Images"
        case .text: return "Text"
        case .file: return "Files"
        case .richText: return "Rich text"
        case .pdf: return "PDFs"
        case .other: return "Other"
        }
    }

    public static func tag(_ kind: ContentKind) -> TaggedContent {
        switch kind {
        case .image:
            return TaggedContent(tags: [.image], isSensitive: false)
        case .text(let raw):
            return tag(text: raw)
        }
    }

    public static func tag(text: String) -> TaggedContent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tags = Set<ContentTag>()

        if trimmed.isEmpty {
            return TaggedContent(tags: [.text], isSensitive: false)
        }

        if looksLikeURL(trimmed) { tags.insert(.url) }
        if looksLikeEmail(trimmed) { tags.insert(.email) }
        if looksLikePhone(trimmed) { tags.insert(.phone) }
        if looksLikeSHA(trimmed) { tags.insert(.sha) }
        if looksLikeIBAN(trimmed) { tags.insert(.iban) }
        if looksLikeCreditCard(trimmed) { tags.insert(.creditCard) }
        if looksLikeBearer(trimmed) { tags.insert(.bearerToken) }
        if looksLikeAPIKey(trimmed) { tags.insert(.apiKey) }
        if looksLikePassword(trimmed) { tags.insert(.password) }
        if looksLikeJSON(trimmed) { tags.insert(.json) }
        if looksLikeFilePath(trimmed) { tags.insert(.filePath) }
        if looksLikeColorHex(trimmed) { tags.insert(.colorHex) }
        if looksLikeAmount(trimmed) { tags.insert(.amount) }
        if OTPDetector.extract(from: trimmed) != nil { tags.insert(.otp) }
        tags.formUnion(embeddedSensitiveTags(in: trimmed))

        if tags.isEmpty { tags.insert(.text) }

        let sensitive = !tags.isDisjoint(with: SensitivePrivacySettings.protectedTags)
        return TaggedContent(tags: tags, isSensitive: sensitive)
    }

    /// Finds sensitive tokens embedded in longer notes (e.g. "IBAN DE89…").
    public static func embeddedSensitiveTags(in text: String) -> Set<ContentTag> {
        var tags = Set<ContentTag>()
        let compact = text.replacingOccurrences(of: " ", with: "").uppercased()
        if compact.range(of: #"[A-Z]{2}\d{2}[A-Z0-9]{10,30}"#, options: .regularExpression) != nil {
            tags.insert(.iban)
        }
        let digitsOnlyRuns = text.split(whereSeparator: { !$0.isNumber })
        for run in digitsOnlyRuns {
            let d = String(run)
            if d.count >= 13, d.count <= 19, luhn(d) {
                tags.insert(.creditCard)
            }
        }
        if text.range(
            of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            tags.insert(.email)
        }
        if text.range(of: #"\+?[\d\s().-]{10,}"#, options: .regularExpression) != nil {
            let digits = text.filter(\.isNumber)
            if digits.count >= 10, digits.count <= 15 {
                tags.insert(.phone)
            }
        }
        if text.range(
            of: #"(?:[$€£]\s?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?|\d+[.,]\d{2}\s?(?:USD|EUR|GBP|\$|€|£))"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            tags.insert(.amount)
        }
        return tags
    }

    private static func looksLikeAmount(_ s: String) -> Bool {
        s.range(
            of: #"^[$€£]?\s?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?\s?(?:USD|EUR|GBP)?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func looksLikeURL(_ s: String) -> Bool {
        if let url = URL(string: s), url.scheme == "http" || url.scheme == "https", url.host != nil {
            return true
        }
        return s.range(of: #"^(https?://|www\.)\S+"#, options: .regularExpression) != nil
    }

    private static func looksLikeEmail(_ s: String) -> Bool {
        s.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func looksLikePhone(_ s: String) -> Bool {
        let digits = s.filter(\.isNumber)
        guard digits.count >= 10, digits.count <= 15 else { return false }
        return s.range(of: #"^\+?[\d\s().-]{10,}$"#, options: .regularExpression) != nil
    }

    private static func looksLikeSHA(_ s: String) -> Bool {
        let hex = s.lowercased()
        let lengths: Set<Int> = [40, 64, 128]
        guard lengths.contains(hex.count) else { return false }
        return hex.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "0123456789abcdef").contains($0) }
    }

    private static func looksLikeIBAN(_ s: String) -> Bool {
        let compact = s.replacingOccurrences(of: " ", with: "").uppercased()
        return compact.range(of: #"^[A-Z]{2}\d{2}[A-Z0-9]{10,30}$"#, options: .regularExpression) != nil
    }

    private static func looksLikeCreditCard(_ s: String) -> Bool {
        let digits = s.filter(\.isNumber)
        guard digits.count >= 13, digits.count <= 19 else { return false }
        return luhn(digits)
    }

    private static func luhn(_ digits: String) -> Bool {
        var sum = 0
        let reversed = digits.reversed().map { Int(String($0)) ?? 0 }
        for (i, d) in reversed.enumerated() {
            var v = d
            if i % 2 == 1 {
                v *= 2
                if v > 9 { v -= 9 }
            }
            sum += v
        }
        return sum % 10 == 0
    }

    private static func looksLikeBearer(_ s: String) -> Bool {
        s.range(of: #"^(Bearer\s+)?[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$"#, options: [.regularExpression, .caseInsensitive]) != nil
            || s.lowercased().hasPrefix("bearer ")
    }

    private static func looksLikeAPIKey(_ s: String) -> Bool {
        let lower = s.lowercased()
        if lower.hasPrefix("sk-") || lower.hasPrefix("pk_") || lower.hasPrefix("api_") { return true }
        if lower.contains("api_key") || lower.contains("apikey") { return true }
        return s.range(of: #"^(sk|pk|rk|key)[_-][A-Za-z0-9]{16,}$"#, options: .regularExpression) != nil
    }

    private static func looksLikePassword(_ s: String) -> Bool {
        if s.count < 8 || s.contains(" ") { return false }
        if looksLikeURL(s) || looksLikeEmail(s) || looksLikeSHA(s) { return false }
        let hasLetter = s.rangeOfCharacter(from: .letters) != nil
        let hasDigit = s.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbol = s.unicodeScalars.contains { !$0.properties.isAlphabetic && !CharacterSet.decimalDigits.contains($0) && $0 != " " }
        return hasLetter && hasDigit && (hasSymbol || s.count >= 12)
    }

    private static func looksLikeJSON(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]")) else { return false }
        guard let data = t.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func looksLikeFilePath(_ s: String) -> Bool {
        s.hasPrefix("/") || s.hasPrefix("~/") || s.range(of: #"^[A-Za-z]:\\"#, options: .regularExpression) != nil
    }

    private static func looksLikeColorHex(_ s: String) -> Bool {
        DetectedContentExtractor.looksLikeColorToken(s)
    }
}
