import Foundation

/// Hosted legal pages for each Buddy app (GitHub Pages).
public enum BuddyLegalURLs {
    public enum App: String, Sendable {
        case clipboardBuddy = "clipboard-buddy"
        case screenshotBuddy = "screenshot-buddy"
        case otpBuddy = "otp-buddy"
    }

    private static let pagesHost = "https://rodrigofranzoi.github.io"

    public static func privacyPolicy(for app: App) -> URL {
        URL(string: "\(pagesHost)/\(app.rawValue)/privacy.html")!
    }

    public static func termsOfUse(for app: App) -> URL {
        URL(string: "\(pagesHost)/\(app.rawValue)/terms.html")!
    }
}
