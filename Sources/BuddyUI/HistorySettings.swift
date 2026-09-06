import SwiftUI
import AppKit
import UniformTypeIdentifiers
import BuddyCore

// MARK: - Clippings / history limits

/// Clipboard Buddy: how many clippings to keep and show in the menu bar.
public struct ClipboardClippingsSettingsSection: View {
    @AppStorage(BuddySettingsKey.clipboardMaxHistoryCount) private var maxHistoryCount =
        ClipboardIgnoreSettings.defaultMaxHistoryCount
    @AppStorage(BuddySettingsKey.clipboardMenuBarRecentCount) private var menuBarRecentCount =
        ClipboardIgnoreSettings.defaultMenuBarRecentCount
    @AppStorage(BuddySettingsKey.clipboardMenuBarFavoriteCount) private var menuBarFavoriteCount =
        ClipboardIgnoreSettings.defaultMenuBarFavoriteCount

    private let onLimitsChanged: (() -> Void)?

    public init(onLimitsChanged: (() -> Void)? = nil) {
        self.onLimitsChanged = onLimitsChanged
    }

    public var body: some View {
        Section {
            Stepper(
                "Remember \(maxHistoryCount) clippings",
                value: $maxHistoryCount,
                in: 10...2000,
                step: 10
            )
            .accessibilityIdentifier("settings-clipboard-max-history")
            .onChange(of: maxHistoryCount) { _ in onLimitsChanged?() }

            Stepper(
                "Show \(menuBarRecentCount) clippings in menu bar",
                value: $menuBarRecentCount,
                in: 1...50
            )
            .accessibilityIdentifier("settings-clipboard-menu-recent")

            Stepper(
                "Show \(menuBarFavoriteCount) favorites in menu bar",
                value: $menuBarFavoriteCount,
                in: 0...50
            )
            .accessibilityIdentifier("settings-clipboard-menu-favorites")
        } header: {
            Text("Clippings")
        } footer: {
            Text("Older clippings beyond the remember limit are removed automatically. Favorites are kept separately.")
                .font(BuddyTheme.Typography.caption)
        }
    }
}

/// Screenshot Buddy: how many shots to keep and show in the menu bar.
public struct ScreenshotHistorySettingsSection: View {
    @AppStorage(BuddySettingsKey.screenshotMaxHistoryCount) private var maxHistoryCount = 100
    @AppStorage(BuddySettingsKey.screenshotMenuBarRecentCount) private var menuBarRecentCount = 8

    private let onLimitsChanged: (() -> Void)?

    public init(onLimitsChanged: (() -> Void)? = nil) {
        self.onLimitsChanged = onLimitsChanged
    }

    public var body: some View {
        Section {
            Stepper(
                "Remember \(maxHistoryCount) screenshots",
                value: $maxHistoryCount,
                in: 10...2000,
                step: 10
            )
            .accessibilityIdentifier("settings-screenshot-max-history")
            .onChange(of: maxHistoryCount) { _ in onLimitsChanged?() }

            Stepper(
                "Show \(menuBarRecentCount) screenshots in menu bar",
                value: $menuBarRecentCount,
                in: 1...50
            )
            .accessibilityIdentifier("settings-screenshot-menu-recent")
        } header: {
            Text("Screenshots")
        } footer: {
            Text("Older screenshots beyond the remember limit are removed automatically.")
                .font(BuddyTheme.Typography.caption)
        }
    }
}

// MARK: - Ignore apps

/// Apps whose clipboard copies are not saved into history.
public struct ClipboardIgnoredAppsSettingsSection: View {
    @State private var apps: [IgnoredClipboardApp] = ClipboardIgnoreSettings.ignoredApps

    public init() {}

    public var body: some View {
        Section {
            if apps.isEmpty {
                Text("No apps ignored")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(apps) { app in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                            Text(app.bundleIdentifier)
                                .font(BuddyTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            ClipboardIgnoreSettings.remove(bundleIdentifier: app.bundleIdentifier)
                            reload()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Stop ignoring \(app.displayName)")
                        .accessibilityIdentifier("settings-ignore-remove-\(app.bundleIdentifier)")
                    }
                }
            }

            Button("Add App…") {
                addApp()
            }
            .accessibilityIdentifier("settings-ignore-add-app")
        } header: {
            Text("Ignored Apps")
        } footer: {
            Text("Copies made while these apps are frontmost are not saved to Clipboard Buddy history.")
                .font(BuddyTheme.Typography.caption)
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        apps = ClipboardIgnoreSettings.ignoredApps
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose apps whose clipboard copies should be ignored"
        panel.prompt = "Ignore"
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier,
                  !bundleID.isEmpty
            else { continue }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            ClipboardIgnoreSettings.add(
                IgnoredClipboardApp(bundleIdentifier: bundleID, displayName: name)
            )
        }
        reload()
    }
}

// MARK: - Clear history

/// Destructive “erase all history” control for Settings.
public struct BuddyClearHistorySettingsSection: View {
    private let itemNoun: String
    private let onClear: () -> Void
    @State private var confirm = false

    public init(itemNoun: String, onClear: @escaping () -> Void) {
        self.itemNoun = itemNoun
        self.onClear = onClear
    }

    public var body: some View {
        Section {
            Button("Erase All History…", role: .destructive) {
                confirm = true
            }
            .accessibilityIdentifier("settings-erase-all-history")
        } header: {
            Text("History")
        } footer: {
            Text("Removes all saved \(itemNoun) from this Mac. This cannot be undone.")
                .font(BuddyTheme.Typography.caption)
        }
        .confirmationDialog(
            "Erase all \(itemNoun)?",
            isPresented: $confirm,
            titleVisibility: .visible
        ) {
            Button("Erase All", role: .destructive) {
                onClear()
            }
            .accessibilityIdentifier("settings-erase-all-confirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

/// Menu-bar / toolbar control that clears history after confirmation.
public struct BuddyClearHistoryButton: View {
    private let itemNoun: String
    private let style: Style
    private let onClear: () -> Void
    @State private var confirm = false

    public enum Style {
        case menuBar
        case toolbar
    }

    public init(itemNoun: String, style: Style = .menuBar, onClear: @escaping () -> Void) {
        self.itemNoun = itemNoun
        self.style = style
        self.onClear = onClear
    }

    public var body: some View {
        Group {
            switch style {
            case .menuBar:
                Button(role: .destructive) {
                    confirmEraseWithAlert()
                } label: {
                    Label("Erase All History…", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal)
                .padding(.vertical, BuddyTheme.Spacing.sm)
            case .toolbar:
                Button(role: .destructive) {
                    confirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Erase all history")
                .confirmationDialog(
                    "Erase all \(itemNoun)?",
                    isPresented: $confirm,
                    titleVisibility: .visible
                ) {
                    Button("Erase All", role: .destructive) {
                        onClear()
                    }
                    .accessibilityIdentifier("erase-all-history-confirm")
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This cannot be undone.")
                }
            }
        }
        .accessibilityIdentifier("erase-all-history")
        .accessibilityLabel("Erase all history")
    }

    private func confirmEraseWithAlert() {
        let alert = NSAlert()
        alert.messageText = "Erase all \(itemNoun)?"
        alert.informativeText = "This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Erase All")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            onClear()
        }
    }
}
