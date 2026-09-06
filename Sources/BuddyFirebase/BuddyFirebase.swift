import Foundation
import BuddyCore
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

/// Firebase façade for *-buddy macOS apps (Spark / free tier: Analytics + Crashlytics).
/// Never logs clipboard contents, email bodies, or OTP codes.
public enum BuddyFirebase {
    public private(set) static var isConfigured = false

    public static func configure() {
        guard FirebaseApp.app() == nil else {
            isConfigured = true
            return
        }
        // Requires GoogleService-Info.plist in the app bundle. Skip quietly when absent
        // (e.g. incomplete local builds / marketing capture harnesses).
        let hasPlist = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        guard hasPlist else {
            #if DEBUG
            print("[BuddyFirebase] Skipping configure — GoogleService-Info.plist not in bundle")
            #endif
            return
        }
        FirebaseApp.configure()
        isConfigured = true
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Analytics.setAnalyticsCollectionEnabled(true)
    }

    public static func log(event: String, parameters: [String: String] = [:]) {
        let safe = parameters.filter {
            let k = $0.key.lowercased()
            return !k.contains("content") && !k.contains("code") && !k.contains("password")
                && !k.contains("email") && !k.contains("token")
        }
        #if DEBUG
        print("[BuddyFirebase] \(event) \(safe)")
        #endif
        guard isConfigured else { return }
        var params: [String: Any] = [:]
        for (k, v) in safe { params[k] = v }
        Analytics.logEvent(event, parameters: params.isEmpty ? nil : params)
    }

    public static func recordBreadcrumb(_ message: String) {
        guard isConfigured else { return }
        let safe = String(message.prefix(100))
        Crashlytics.crashlytics().log(safe)
    }

    public enum Event {
        public static let appLaunch = "app_launch"
        public static let favoriteCopied = "favorite_copied"
        public static let otpDetected = "otp_detected"
        public static let screenshotExported = "screenshot_exported"
        public static let sensitiveRevealed = "sensitive_revealed"
        public static let contentBlocked = "content_blocked"
    }
}
