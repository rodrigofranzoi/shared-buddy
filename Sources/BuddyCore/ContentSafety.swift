import Foundation
import AppKit
import Vision

/// Blocks pornography and sexual content. Violent / profane language is allowed.
public struct ContentSafetyResult: Sendable, Equatable {
    public let isBlocked: Bool

    public static let allowed = ContentSafetyResult(isBlocked: false)
    public static let blocked = ContentSafetyResult(isBlocked: true)

    public init(isBlocked: Bool) {
        self.isBlocked = isBlocked
    }
}

public enum ContentSafety {
    public static var neverShowWarning: Bool {
        get { UserDefaults.standard.bool(forKey: BuddySettingsKey.contentWarningNeverShow) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.contentWarningNeverShow) }
    }

    /// Evaluate plain text. Does not treat violence or non-sexual profanity as blocked.
    public static func evaluate(text: String) -> ContentSafetyResult {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .allowed
        }

        if containsBlockedPhrase(in: normalized) { return .blocked }
        if containsBlockedWord(in: normalized) { return .blocked }
        if containsBlockedDomain(in: normalized) { return .blocked }
        return .allowed
    }

    /// Evaluate image bytes via on-device OCR, then the same sexual-content text policy.
    public static func evaluate(imageData: Data) -> ContentSafetyResult {
        guard let image = NSImage(data: imageData) else { return .allowed }
        return evaluate(image: image)
    }

    public static func evaluate(image: NSImage) -> ContentSafetyResult {
        let text = recognizeText(in: image)
        guard !text.isEmpty else { return .allowed }
        return evaluate(text: text)
    }

    public static func evaluate(imageData: Data) async -> ContentSafetyResult {
        await Task.detached(priority: .userInitiated) {
            evaluate(imageData: imageData)
        }.value
    }

    /// Posts a toolbar warning unless the user opted out.
    public static func notifyBlocked() {
        guard !neverShowWarning else { return }
        NotificationCenter.default.post(name: .buddyContentBlocked, object: nil)
    }

    // MARK: - Private

    /// Multi-word / distinctive phrases (matched as substrings on lowercased text).
    private static let blockedPhrases: [String] = [
        "pornography", "pornographic", "pornhub", "porn hub",
        "onlyfans", "only fans", "chaturbate", "xvideos", "xhamster",
        "redtube", "youporn", "xnxx", "brazzers", "spankbang",
        "adult video", "adult film", "sex tape", "sextoy", "sex toy",
        "cam girl", "camgirl", "cam boy", "camboy",
        "send nudes", "nude photo", "nude pics", "nude pic",
        "blow job", "blowjob", "hand job", "handjob",
        "cum shot", "cumshot", "deepthroat", "deep throat",
        "gangbang", "gang bang", "creampie", "cream pie",
        "hardcore porn", "softcore porn", "hentai porn",
        "erotic massage", "escorts near", "escort service",
        "nsfw content", "xxx video", "xxx porn"
    ]

    /// Whole-word tokens. Short ambiguous slang is omitted to limit false positives.
    private static let blockedWords: [String] = [
        "porn", "porno", "xxx", "nsfw", "hentai", "erotica", "erotic",
        "nude", "nudes", "nudity", "naked",
        "orgasm", "orgasms", "masturbate", "masturbation", "masturbating",
        "fetish", "fetishes", "bdsm", "bondage",
        "boobs", "tits", "titties", "pussy", "vagina", "penis", "clitoris",
        "dildo", "vibrator", "fleshlight",
        "blowjob", "handjob", "handjobs", "blowjobs",
        "cumshot", "creampie", "gangbang",
        "camgirl", "camboy", "onlyfans",
        "sex", "sexual", "sexually", "sexuality", "sexy",
        "intercourse", "pornstar", "pornstars",
        "stripper", "strippers", "striptease",
        "hooker", "prostitutes", "prostitution"
    ]

    private static let blockedDomains: [String] = [
        "pornhub.com", "xvideos.com", "xhamster.com", "xnxx.com",
        "redtube.com", "youporn.com", "chaturbate.com", "onlyfans.com",
        "brazzers.com", "spankbang.com", "porn.com", "xxx.com",
        "stripchat.com", "livejasmin.com", "manyvids.com"
    ]

    private static func containsBlockedPhrase(in text: String) -> Bool {
        blockedPhrases.contains { text.contains($0) }
    }

    private static func containsBlockedWord(in text: String) -> Bool {
        for word in blockedWords {
            let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: word) + #"\b"#
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private static func containsBlockedDomain(in text: String) -> Bool {
        blockedDomains.contains { text.contains($0) }
    }

    private static func recognizeText(in image: NSImage) -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }
        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

extension Notification.Name {
    public static let buddyContentBlocked = Notification.Name("buddy.content.blocked")
}
