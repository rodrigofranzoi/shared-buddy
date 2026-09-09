import Foundation

/// Hosted legal pages for each Buddy app (GitHub Pages).
public enum BuddyLegalURLs {
    public enum App: String, Sendable {
        case clipboardBuddy = "clipboard-buddy"
        case screenshotBuddy = "screenshot-buddy"
        case otpBuddy = "otp-buddy"
        case paintBuddy = "paint-buddy"
    }

    private static let pagesHost = "https://rodrigofranzoi.github.io"

    public static func privacyPolicy(for app: App) -> URL {
        URL(string: "\(pagesHost)/\(app.rawValue)/privacy.html")!
    }

    public static func termsOfUse(for app: App) -> URL {
        URL(string: "\(pagesHost)/\(app.rawValue)/terms.html")!
    }

    /// Numeric App Store Connect Apple ID (not the bundle ID).
    public static func appStoreID(for app: App) -> String? {
        switch app {
        case .clipboardBuddy: return "6809226741"
        case .screenshotBuddy: return "6809226358"
        case .otpBuddy: return "6809226854"
        case .paintBuddy: return "6809586126"
        }
    }

    /// Opens the App Store write-review page when an App Store ID is known.
    public static func writeReviewURL(for app: App) -> URL? {
        guard let id = appStoreID(for: app) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }
}
