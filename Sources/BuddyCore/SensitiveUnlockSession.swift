import Foundation
import LocalAuthentication
import Combine

/// Session unlock for sensitive content. A successful auth (or no-auth reveal)
/// keeps content visible for ``unlockDuration`` so Touch ID is not needed every tap.
@MainActor
public final class SensitiveUnlockSession: ObservableObject {
    public static let shared = SensitiveUnlockSession()

    /// Ten-minute allowance after unlock.
    public static let unlockDuration: TimeInterval = 10 * 60

    @Published public private(set) var unlockedUntil: Date?

    public var isUnlocked: Bool {
        guard let until = unlockedUntil else { return false }
        return until > Date()
    }

    private var expiryTimer: Timer?

    public init() {}

    /// Whether UI should hide this sensitive item right now.
    /// Only when passcode / Touch ID is required; stays visible after unlock for ``unlockDuration``.
    public func shouldHide(isSensitive: Bool) -> Bool {
        guard isSensitive else { return false }
        guard SensitivePrivacySettings.requireAuthSensitiveContent else { return false }
        return !isUnlocked
    }

    /// Reveal sensitive content. Requires Touch ID / password when that setting is on,
    /// then stays open for 10 minutes.
    public func unlock(
        reason: String = "Reveal sensitive content",
        completion: @escaping (Bool) -> Void
    ) {
        if isUnlocked {
            completion(true)
            return
        }

        guard SensitivePrivacySettings.requireAuthSensitiveContent else {
            grantUnlock()
            completion(true)
            return
        }

        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    if success {
                        self.grantUnlock()
                    }
                    completion(success)
                }
            }
        } else {
            // Device has no auth configured — allow reveal rather than brick the UI.
            grantUnlock()
            completion(true)
        }
    }

    public func lock() {
        unlockedUntil = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    private func grantUnlock() {
        let until = Date().addingTimeInterval(Self.unlockDuration)
        unlockedUntil = until
        scheduleExpiry(at: until)
    }

    private func scheduleExpiry(at date: Date) {
        expiryTimer?.invalidate()
        let interval = max(date.timeIntervalSinceNow, 0.1)
        expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }
}
