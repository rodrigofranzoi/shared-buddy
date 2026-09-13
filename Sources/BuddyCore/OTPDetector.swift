import Foundation

public struct OTPMatch: Sendable, Equatable {
    public let code: String
    public let confidence: Double
    /// Lifetime parsed from the message when present (e.g. “valid for 15 minutes”).
    public let validitySeconds: TimeInterval?

    public init(code: String, confidence: Double, validitySeconds: TimeInterval? = nil) {
        self.code = code
        self.confidence = confidence
        self.validitySeconds = validitySeconds
    }
}

/// Conservative OTP extractor for email bodies and short messages.
/// Handles common English + localized OTP phrasing (PT/ES/FR/IT/DE/NL/… ).
public enum OTPDetector {
    /// Folded (diacritic-insensitive) phrases that must appear near an unlabeled digit run.
    private static let proximityHints: [String] = [
        // EN
        "verification code", "one-time", "one time", "one-time passcode", "one time passcode",
        "otp", "passcode", "security code", "login code", "signin code", "sign-in code",
        "2fa", "two-factor", "two factor", "pin code", "pincode", "your pin", "pin:",
        "authentication code", "auth code", "access code",
        // PT
        "codigo de seguranca", "codigo de login", "codigo de verificacao", "codigo de acesso",
        "codigo de autenticacao", "seu codigo", "codigo otp", "senha de uso unico",
        // ES
        "codigo de verificacion", "codigo de seguridad", "codigo de acceso", "codigo de inicio",
        "tu codigo", "codigo otp",
        // FR
        "code de verification", "code de securite", "code de connexion", "code d'acces",
        "code d acces", "votre code", "mot de passe a usage unique",
        // IT
        "codice di verifica", "codice di sicurezza", "codice di accesso", "codice otp",
        "il tuo codice",
        // DE
        "bestätigungscode", "bestaetigungscode", "sicherheitscode", "anmeldecode",
        "einmalcode", "einmaliges passwort", "verifizierungscode",
        // NL
        "verificatiecode", "beveiligingscode", "inlogcode", "eenmalige code",
        // RU
        "код подтверждения", "код безопасности", "одноразовый код", "код входа",
        // JA / ZH (common fragments)
        "認証コード", "確認コード", "セキュリティコード", "ワンタイム",
        "验证码", "驗證碼", "安全代码", "一次性密码",
        // AR
        "رمز التحقق", "رمز الأمان", "رمز الدخول", "كلمة المرور لمرة واحدة"
    ].map(fold)

    public static func extract(from text: String) -> OTPMatch? {
        let validity = extractValiditySeconds(from: text)

        // Labeled patterns require an OTP keyword next to the digits.
        // Include localized spellings (código / codigo / codice / …).
        let patterns: [(pattern: String, base: Double, needsProximity: Bool)] = [
            // "Código de segurança: 315987" / "Security code: 123456" / "Code: 123456"
            (
                #"(?i)(?:c[oóòôõö]digo|codigo|code|otp|passcode|pin|codice|code)\b[^\d]{0,48}(\d{4,8})"#,
                0.85,
                false
            ),
            // "315987 is your code" / "184617 is your PIN"
            (
                #"(?<![A-Za-z0-9])(\d{4,8})[^\d]{0,28}(?:is your |é o seu |e o seu |es tu |ist dein |est votre )?(?:c[oóòôõö]digo|codigo|code|otp|passcode|pin|codice)\b"#,
                0.85,
                false
            ),
            // Explicit strong phrases used by Microsoft / Riot / banks
            (
                #"(?i)(?:c[oóòôõö]digo|codigo)\s+de\s+(?:seguran[cç]a|login|verifica[cç][aã]o|acesso|autentica[cç][aã]o)\s*[:：]?\s*(\d{4,8})"#,
                0.95,
                false
            ),
            (
                #"(?i)(?:security|verification|login|sign[\s-]?in|authentication|access)\s+code\s*[:：]?\s*(\d{4,8})"#,
                0.95,
                false
            ),
            (
                #"(?i)(?:c[oóòôõö]digo|codigo)\s+de\s+(?:verificaci[oó]n|seguridad|acceso|inicio(?:\s+de\s+sesi[oó]n)?)\s*[:：]?\s*(\d{4,8})"#,
                0.95,
                false
            ),
            (
                #"(?i)(?:code\s+de\s+(?:v[eé]rification|s[eé]curit[eé]|connexion|acc[eè]s)|bestätigungscode|bestaetigungscode|sicherheitscode|verificatiecode|beveiligingscode)\s*[:：]?\s*(\d{4,8})"#,
                0.95,
                false
            ),
            // Bare digit runs only with a nearby localized hint.
            (#"(?<![A-Za-z0-9])(\d{6})(?![A-Za-z0-9])"#, 0.45, true),
            (#"(?<![A-Za-z0-9])(\d{4})(?![A-Za-z0-9])"#, 0.30, true),
            (#"(?<![A-Za-z0-9])(\d{8})(?![A-Za-z0-9])"#, 0.45, true)
        ]

        var best: OTPMatch?

        for entry in patterns {
            guard let regex = try? NSRegularExpression(pattern: entry.pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let codeRange = Range(match.range(at: 1), in: text) else { continue }
                let code = String(text[codeRange])
                if isLikelyFalsePositive(code) { continue }
                if entry.needsProximity, !hasNearbyHint(around: codeRange, in: text) { continue }

                var score = entry.base
                if hasNearbyHint(around: codeRange, in: text) { score += 0.3 }
                if code.count == 6 || code.count == 8 { score += 0.1 }
                if best == nil || score > best!.confidence {
                    best = OTPMatch(code: code, confidence: min(score, 1.0), validitySeconds: validity)
                }
            }
        }

        guard let best, best.confidence >= 0.75 else { return nil }
        return best
    }

    /// Parses phrases like “valid for 15 minutes” / “expira em 10 minutos”.
    public static func extractValiditySeconds(from text: String) -> TimeInterval? {
        let patterns = [
            #"(?i)(?:valid for|expires?\s+in|expire\s+in|expira(?:tion)?\s+in|expira\s+em|válido por|valido por|valable\s+(?:pendant|durant)|scade tra|gültig\s+(?:für|noch)|geldig\s+(?:gedurende|voor))\s+(\d+)\s*(seconds?|secs?|s|minutes?|mins?|m|minutos?|minuten|stunden?|heures?|horas?|hours?|hrs?|h)\b"#,
            #"(?i)(\d+)\s*(seconds?|secs?|minutes?|mins?|minutos?|minuten|hours?|hrs?|horas?|heures?)\s+(?:valid|validity|de validade|de validité)\b"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges >= 3,
                  let amountRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let amount = Double(text[amountRange]) else { continue }
            let unit = fold(String(text[unitRange]))
            if unit.hasPrefix("h") || unit.hasPrefix("stunde") { return amount * 3600 }
            if unit.hasPrefix("m") { return amount * 60 }
            return amount
        }
        return nil
    }

    private static func hasNearbyHint(around codeRange: Range<String.Index>, in text: String, window: Int = 100) -> Bool {
        let start = text.index(codeRange.lowerBound, offsetBy: -window, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(codeRange.upperBound, offsetBy: window, limitedBy: text.endIndex) ?? text.endIndex
        let slice = fold(String(text[start..<end]))
        return proximityHints.contains { slice.contains($0) }
    }

    private static func isLikelyFalsePositive(_ code: String) -> Bool {
        guard code.allSatisfy(\.isNumber) else { return true }
        if code == "000000" || code == "123456" || code == "111111" { return true }
        if code.count == 4, let year = Int(code), (1990...2099).contains(year) { return true }
        // Common Microsoft footer / CSS noise
        if code == "521839" || code == "98052" { return true }
        return false
    }

    private static func fold(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }
}
