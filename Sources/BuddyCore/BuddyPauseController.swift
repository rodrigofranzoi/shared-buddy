import Foundation
import Combine

public extension Notification.Name {
    static let buddyPauseDidChange = Notification.Name("buddy.pauseDidChange")
}

/// Common pause durations for “turn off until…”.
public enum BuddyPausePreset: String, CaseIterable, Identifiable, Sendable {
    case fiveMinutes
    case fifteenMinutes
    case twentyMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case eightHours

    public var id: String { rawValue }

    public var duration: TimeInterval {
        switch self {
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .twentyMinutes: return 20 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .eightHours: return 8 * 60 * 60
        }
    }

    public var title: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .twentyMinutes: return "20 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .fourHours: return "4 hours"
        case .eightHours: return "8 hours"
        }
    }
}

/// Controls temporary “turn off” for a Buddy menu-bar app.
@MainActor
public final class BuddyPauseController: ObservableObject {
    public static let shared = BuddyPauseController()

    @Published public private(set) var isPaused = false
    @Published public private(set) var pauseEndsAt: Date?
    @Published public private(set) var isUntilNextSession = false
    @Published public private(set) var isPermanent = false

    /// Invoked whenever pause state flips (e.g. stop/start monitoring).
    public var onPauseChanged: ((Bool) -> Void)?

    private var resumeTimer: Timer?
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Call once at launch. Session pauses never persist; timed / permanent pauses restore.
    public func restorePersistedPauseIfNeeded() {
        if defaults.bool(forKey: BuddySettingsKey.pausePermanently) {
            apply(paused: true, endsAt: nil, sessionOnly: false, permanent: true, persist: false)
            return
        }

        let until = defaults.double(forKey: BuddySettingsKey.pauseUntil)
        guard until > 0 else {
            apply(paused: false, endsAt: nil, sessionOnly: false, permanent: false, persist: false)
            return
        }
        let end = Date(timeIntervalSince1970: until)
        if end > Date() {
            apply(paused: true, endsAt: end, sessionOnly: false, permanent: false, persist: false)
            scheduleResume(at: end)
        } else {
            clearPersistedPause()
            apply(paused: false, endsAt: nil, sessionOnly: false, permanent: false, persist: false)
        }
    }

    public func pauseUntilNextSession() {
        clearPersistedPause()
        resumeTimer?.invalidate()
        resumeTimer = nil
        apply(paused: true, endsAt: nil, sessionOnly: true, permanent: false, persist: false)
    }

    public func pausePermanently() {
        resumeTimer?.invalidate()
        resumeTimer = nil
        defaults.removeObject(forKey: BuddySettingsKey.pauseUntil)
        defaults.set(true, forKey: BuddySettingsKey.pausePermanently)
        apply(paused: true, endsAt: nil, sessionOnly: false, permanent: true, persist: false)
    }

    public func pause(for duration: TimeInterval) {
        guard duration > 0 else {
            resume()
            return
        }
        pauseUntil(Date().addingTimeInterval(duration))
    }

    public func pause(preset: BuddyPausePreset) {
        pause(for: preset.duration)
    }

    public func pauseUntil(_ date: Date) {
        let end = max(date, Date().addingTimeInterval(1))
        defaults.set(false, forKey: BuddySettingsKey.pausePermanently)
        defaults.set(end.timeIntervalSince1970, forKey: BuddySettingsKey.pauseUntil)
        resumeTimer?.invalidate()
        apply(paused: true, endsAt: end, sessionOnly: false, permanent: false, persist: false)
        scheduleResume(at: end)
    }

    public func resume() {
        resumeTimer?.invalidate()
        resumeTimer = nil
        clearPersistedPause()
        apply(paused: false, endsAt: nil, sessionOnly: false, permanent: false, persist: false)
    }

    public var statusSummary: String {
        guard isPaused else { return "On" }
        if isPermanent { return "Off permanently" }
        if isUntilNextSession { return "Off until next session" }
        if let pauseEndsAt {
            return "Off until \(pauseEndsAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Off"
    }

    private func scheduleResume(at date: Date) {
        resumeTimer?.invalidate()
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            resume()
            return
        }
        resumeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
        }
    }

    private func clearPersistedPause() {
        defaults.removeObject(forKey: BuddySettingsKey.pauseUntil)
        defaults.set(false, forKey: BuddySettingsKey.pausePermanently)
    }

    private func apply(
        paused: Bool,
        endsAt: Date?,
        sessionOnly: Bool,
        permanent: Bool,
        persist: Bool
    ) {
        let changed = isPaused != paused
            || isPermanent != permanent
            || isUntilNextSession != sessionOnly
            || pauseEndsAt != endsAt
        isPaused = paused
        pauseEndsAt = endsAt
        isUntilNextSession = sessionOnly
        isPermanent = permanent
        if persist, let endsAt, !sessionOnly, !permanent {
            defaults.set(endsAt.timeIntervalSince1970, forKey: BuddySettingsKey.pauseUntil)
        }
        if changed {
            onPauseChanged?(paused)
            NotificationCenter.default.post(name: .buddyPauseDidChange, object: self)
        }
    }
}
