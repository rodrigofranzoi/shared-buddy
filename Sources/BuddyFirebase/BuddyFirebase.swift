import Foundation

/// Lightweight Firebase façade. Apps call `configure()` at launch.
/// When GoogleService-Info.plist is absent (local/CI), methods no-op so builds stay green.
public enum BuddyFirebase {
    public private(set) static var isConfigured = false

    public static func configure() {
        // Real FirebaseApp.configure() is linked by host apps that add the Firebase SPM products.
        // This wrapper stays dependency-free so `swift test` works without Firebase binaries.
        isConfigured = true
        log(event: "firebase_configure", parameters: [:])
    }

    public static func log(event: String, parameters: [String: String] = [:]) {
        #if DEBUG
        let safe = parameters.filter { !$0.key.lowercased().contains("content") && !$0.key.lowercased().contains("code") }
        print("[BuddyFirebase] \(event) \(safe)")
        #endif
    }

    public static func recordBreadcrumb(_ message: String) {
        #if DEBUG
        print("[BuddyFirebase:breadcrumb] \(message)")
        #endif
    }

    public enum Event {
        public static let appLaunch = "app_launch"
        public static let favoriteCopied = "favorite_copied"
        public static let otpDetected = "otp_detected"
        public static let screenshotExported = "screenshot_exported"
        public static let sensitiveRevealed = "sensitive_revealed"
    }
}
