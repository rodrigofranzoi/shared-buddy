import Foundation

public enum BuddyLocale: String, CaseIterable, Sendable {
    case en, nl, pt, es, fr, it, ar, zh, ru, ja

    public static let supported: [BuddyLocale] = Array(BuddyLocale.allCases)

    public var isRTL: Bool { self == .ar }

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .nl: return "Nederlands"
        case .pt: return "Português"
        case .es: return "Español"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .ar: return "العربية"
        case .zh: return "中文"
        case .ru: return "Русский"
        case .ja: return "日本語"
        }
    }
}

public enum BuddyLocaleRuntime {
    public static var isRTL: Bool {
        Locale.current.language.languageCode?.identifier == "ar"
            || Locale.current.language.languageCode?.identifier == BuddyLocale.ar.rawValue
    }
}
