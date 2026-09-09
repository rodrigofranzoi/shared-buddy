import Foundation

/// Tracks launches / engagement and decides when to ask for an App Store rating.
///
/// The system may ignore `requestReview` calls; this only throttles how often we *ask*.
public struct BuddyAppReviewPrompt {
    public struct Configuration: Sendable {
        public var minimumLaunches: Int
        public var minimumSignificantEvents: Int
        public var minimumDaysSinceFirstLaunch: Double
        public var minimumDaysBetweenPrompts: Double

        public init(
            minimumLaunches: Int = 4,
            minimumSignificantEvents: Int = 10,
            minimumDaysSinceFirstLaunch: Double = 3,
            minimumDaysBetweenPrompts: Double = 60
        ) {
            self.minimumLaunches = minimumLaunches
            self.minimumSignificantEvents = minimumSignificantEvents
            self.minimumDaysSinceFirstLaunch = minimumDaysSinceFirstLaunch
            self.minimumDaysBetweenPrompts = minimumDaysBetweenPrompts
        }
    }

    private let defaults: UserDefaults
    private let configuration: Configuration
    private let now: () -> Date

    public static let shared = BuddyAppReviewPrompt()

    public init(
        defaults: UserDefaults = .standard,
        configuration: Configuration = Configuration(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.configuration = configuration
        self.now = now
    }

    public func recordLaunch() {
        if defaults.object(forKey: BuddySettingsKey.reviewFirstLaunchAt) == nil {
            defaults.set(now().timeIntervalSince1970, forKey: BuddySettingsKey.reviewFirstLaunchAt)
        }
        let count = defaults.integer(forKey: BuddySettingsKey.reviewLaunchCount)
        defaults.set(count + 1, forKey: BuddySettingsKey.reviewLaunchCount)
    }

    public func recordSignificantEvent() {
        let count = defaults.integer(forKey: BuddySettingsKey.reviewSignificantEventCount)
        defaults.set(count + 1, forKey: BuddySettingsKey.reviewSignificantEventCount)
    }

    public func shouldPrompt(hasAppStoreListing: Bool) -> Bool {
        guard hasAppStoreListing else { return false }
        // Same launch arg as `BuddyMarketingCapture.argument` (avoid MainActor coupling).
        guard !ProcessInfo.processInfo.arguments.contains("-BuddyMarketingCapture") else {
            return false
        }

        let launches = defaults.integer(forKey: BuddySettingsKey.reviewLaunchCount)
        let events = defaults.integer(forKey: BuddySettingsKey.reviewSignificantEventCount)
        guard launches >= configuration.minimumLaunches || events >= configuration.minimumSignificantEvents else {
            return false
        }

        let firstLaunch = defaults.double(forKey: BuddySettingsKey.reviewFirstLaunchAt)
        guard firstLaunch > 0 else { return false }
        let daysSinceFirst = now().timeIntervalSince1970 - firstLaunch
        guard daysSinceFirst >= configuration.minimumDaysSinceFirstLaunch * 86_400 else {
            return false
        }

        let lastPrompt = defaults.double(forKey: BuddySettingsKey.reviewLastPromptAt)
        if lastPrompt > 0 {
            let daysSincePrompt = now().timeIntervalSince1970 - lastPrompt
            guard daysSincePrompt >= configuration.minimumDaysBetweenPrompts * 86_400 else {
                return false
            }
        }

        return true
    }

    public func markPrompted() {
        defaults.set(now().timeIntervalSince1970, forKey: BuddySettingsKey.reviewLastPromptAt)
    }

    /// Records a meaningful action and asks visible UI to consider showing the review prompt.
    public static func recordSignificantEventAndConsiderPrompt() {
        shared.recordSignificantEvent()
        NotificationCenter.default.post(name: .buddyConsiderAppReview, object: nil)
    }
}

public extension Notification.Name {
    /// Posted after a meaningful user action so an on-screen view can consider prompting.
    static let buddyConsiderAppReview = Notification.Name("buddy.considerAppReview")
}
