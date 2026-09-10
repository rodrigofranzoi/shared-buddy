import AppKit
import SwiftUI
import BuddyCore
import BuddyLocalization

/// Shows / re-shows the SwiftUI `WindowGroup` main window for menu-bar (LSUIElement) apps.
///
/// Dock policy:
/// - Opening a window → `.regular` (Dock icon + app menu / Cmd+Q)
/// - Closing the last window → `.accessory` (menu-bar only; app stays running)
/// - Quit only via menu-bar Quit or Cmd+Q while the Dock icon is visible
@MainActor
public enum BuddyMainWindow {
    private static weak var registered: NSWindow?
    private static var didInstallObservers = false

    /// Keep a strong-ish reference path: window stays alive after close so it can be reordered.
    public static func register(_ window: NSWindow) {
        window.isReleasedWhenClosed = false
        registered = window
        installObserversIfNeeded()
    }

    public static func show() {
        presentInDock()
        NSApp.activate(ignoringOtherApps: true)
        if let registered {
            registered.makeKeyAndOrderFront(nil)
            return
        }
        if let window = NSApp.windows.first(where: isMainContentWindow) {
            register(window)
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    /// Like `show()`, but retries briefly until the SwiftUI `WindowGroup` has created a window.
    public static func showWhenReady(attempts: Int = 20, intervalNanoseconds: UInt64 = 50_000_000) {
        presentInDock()
        NSApp.activate(ignoringOtherApps: true)
        if registered != nil || NSApp.windows.contains(where: isMainContentWindow) {
            show()
            return
        }
        guard attempts > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
            showWhenReady(attempts: attempts - 1, intervalNanoseconds: intervalNanoseconds)
        }
    }

    public static func hideOnLaunchIfNeeded() {
        installObserversIfNeeded()
        DispatchQueue.main.async {
            for window in NSApp.windows where isMainContentWindow(window) {
                register(window)
                window.orderOut(nil)
            }
            retreatToMenuBarIfNeeded()
        }
    }

    /// First launch: show the main window (Dock + UI). Later launches: menu-bar pin only.
    public static func prepareMenuBarLaunch(isFirstLaunch: Bool) {
        if isFirstLaunch {
            installObserversIfNeeded()
            showWhenReady()
        } else {
            hideOnLaunchIfNeeded()
        }
    }

    /// First open: main window + launch-at-login consent. Later opens: status-item pin only.
    public static func presentFirstLaunchExperienceIfNeeded(appDisplayName: String) {
        guard !BuddyMarketingCapture.isEnabled else { return }
        let firstLaunch = BuddyLaunchAtLogin.needsConsentPrompt
        if firstLaunch {
            installObserversIfNeeded()
            // Wait for WindowGroup registration, then show + consent (modal).
            Task { @MainActor in
                for _ in 0..<20 {
                    if registered != nil || NSApp.windows.contains(where: isMainContentWindow) {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                show()
                // Yield so the window can paint before the blocking alert.
                try? await Task.sleep(nanoseconds: 100_000_000)
                _ = BuddyLaunchAtLogin.promptForConsentIfNeeded(appDisplayName: appDisplayName)
            }
        } else {
            hideOnLaunchIfNeeded()
        }
    }

    /// Show the Dock icon and standard app menu (enables Cmd+Q).
    public static func presentInDock() {
        guard NSApp.activationPolicy() != .regular else { return }
        NSApp.setActivationPolicy(.regular)
    }

    /// Hide the Dock icon while keeping the menu-bar status item.
    public static func retreatToMenuBarIfNeeded(excluding closing: NSWindow? = nil) {
        guard !hasVisibleAppWindows(excluding: closing) else { return }
        guard NSApp.activationPolicy() != .accessory else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    private static func installObserversIfNeeded() {
        guard !didInstallObservers else { return }
        didInstallObservers = true

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            let window = notification.object as? NSWindow
            Task { @MainActor in
                guard let window, isAppWindow(window) else { return }
                // Closing windows can still report isVisible during willClose.
                retreatToMenuBarIfNeeded(excluding: window)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            let window = notification.object as? NSWindow
            Task { @MainActor in
                guard let window, isAppWindow(window), window.isVisible else { return }
                presentInDock()
            }
        }
    }

    private static func hasVisibleAppWindows(excluding closing: NSWindow? = nil) -> Bool {
        NSApp.windows.contains { window in
            guard window !== closing else { return false }
            return isAppWindow(window) && window.isVisible
        }
    }

    private static func isAppWindow(_ window: NSWindow) -> Bool {
        guard window.styleMask.contains(.titled) else { return false }
        guard window.contentView != nil else { return false }
        return true
    }

    private static func isMainContentWindow(_ window: NSWindow) -> Bool {
        guard isAppWindow(window) else { return false }
        return window.frame.width >= 400
    }
}

/// Attach to the main window root so the window can be reopened after the user closes it.
public struct BuddyMainWindowRegistrar: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                BuddyMainWindow.register(window)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            BuddyMainWindow.register(window)
        }
    }
}

public extension Notification.Name {
    /// Close the menu-bar NSPopover (e.g. before opening Preferences from the pin).
    static let buddyDismissMenuBarPopover = Notification.Name("buddy.dismissMenuBarPopover")
}

/// Menu-bar footer: open the main window, Preferences, + quit the app.
public struct BuddyMenuBarAppControls: View {
    public let appName: String
    public var brand: BuddyBrand?
    public var onOpen: (() -> Void)?
    public var onQuit: (() -> Void)?

    public init(
        appName: String,
        brand: BuddyBrand? = nil,
        onOpen: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil
    ) {
        self.appName = appName
        self.brand = brand
        self.onOpen = onOpen
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Button {
                onOpen?()
                BuddyMainWindow.show()
            } label: {
                Label {
                    Text("Open \(appName)", bundle: BuddyL10n.bundle)
                } icon: {
                    Image(systemName: "macwindow")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.vertical, BuddyTheme.Spacing.sm)
            .accessibilityIdentifier("menu-bar-open-app")

            BuddyMenuBarPreferencesButton()

            if let brand,
               let reviewURL = BuddyLegalURLs.writeReviewURL(for: brand.legalApp) {
                Button {
                    NSWorkspace.shared.open(reviewURL)
                } label: {
                    Label {
                        Text("Rate \(appName)", bundle: BuddyL10n.bundle)
                    } icon: {
                        Image(systemName: "star")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal)
                .padding(.vertical, BuddyTheme.Spacing.sm)
                .accessibilityIdentifier("menu-bar-rate-app")
            }

            Button {
                onQuit?()
                NSApp.terminate(nil)
            } label: {
                Label {
                    Text("Quit \(appName)", bundle: BuddyL10n.bundle)
                } icon: {
                    Image(systemName: "power")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.bottom, BuddyTheme.Spacing.sm)
            .accessibilityIdentifier("menu-bar-quit-app")
        }
    }
}

/// Preferences control for the menu-bar pin: dismisses the popover, then opens Settings.
private struct BuddyMenuBarPreferencesButton: View {
    var body: some View {
        Button {
            NotificationCenter.default.post(name: .buddyDismissMenuBarPopover, object: nil)
            DispatchQueue.main.async {
                buddyOpenAppSettings()
            }
        } label: {
            Label {
                Text("Preferences", bundle: BuddyL10n.bundle)
            } icon: {
                Image(systemName: "gearshape")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.vertical, BuddyTheme.Spacing.sm)
        .accessibilityIdentifier("menu-bar-preferences")
        .help(Text("Preferences", bundle: BuddyL10n.bundle))
    }
}
