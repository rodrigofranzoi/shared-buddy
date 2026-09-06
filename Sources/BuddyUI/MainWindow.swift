import AppKit
import SwiftUI

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

/// Menu-bar footer: open the main window + quit the app.
public struct BuddyMenuBarAppControls: View {
    public let appName: String
    public var onOpen: (() -> Void)?
    public var onQuit: (() -> Void)?

    public init(
        appName: String,
        onOpen: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil
    ) {
        self.appName = appName
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
                Label("Open \(appName)", systemImage: "macwindow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.vertical, BuddyTheme.Spacing.sm)
            .accessibilityIdentifier("menu-bar-open-app")

            Button {
                onQuit?()
                NSApp.terminate(nil)
            } label: {
                Label("Quit \(appName)", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.bottom, BuddyTheme.Spacing.sm)
            .accessibilityIdentifier("menu-bar-quit-app")
        }
    }
}
