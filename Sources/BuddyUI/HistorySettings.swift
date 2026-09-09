import SwiftUI
import AppKit
import UniformTypeIdentifiers
import BuddyCore
import BuddyLocalization

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
            Stepper(value: $maxHistoryCount, in: 10...2000, step: 10) {
                Text("Remember \(maxHistoryCount) clippings", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-clipboard-max-history")
            .onChange(of: maxHistoryCount) { _ in onLimitsChanged?() }

            Stepper(value: $menuBarRecentCount, in: 1...50) {
                Text("Show \(menuBarRecentCount) clippings in menu bar", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-clipboard-menu-recent")

            Stepper(value: $menuBarFavoriteCount, in: 0...50) {
                Text("Show \(menuBarFavoriteCount) favorites in menu bar", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-clipboard-menu-favorites")
        } header: {
            Text("Clippings", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "Older clippings beyond the remember limit are removed automatically. Favorites are kept separately.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
        }
    }
}

/// Screenshot Buddy: how many shots to keep and show in the menu bar.
public struct ScreenshotHistorySettingsSection: View {
    @AppStorage(BuddySettingsKey.screenshotMaxHistoryCount) private var maxHistoryCount = 100
    @AppStorage(BuddySettingsKey.screenshotMenuBarRecentCount) private var menuBarRecentCount = 8
    @State private var maxHistoryDraft = ""
    @FocusState private var maxHistoryFocused: Bool

    private let onLimitsChanged: (() -> Void)?
    private let maxHistoryRange = 10...2000
    private let menuBarRecentRange = 1...50

    public init(onLimitsChanged: (() -> Void)? = nil) {
        self.onLimitsChanged = onLimitsChanged
    }

    public var body: some View {
        Section {
            HStack {
                Text("Remember screenshots", bundle: BuddyL10n.bundle)
                Spacer(minLength: BuddyTheme.Spacing.sm)
                TextField("", text: $maxHistoryDraft)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .focused($maxHistoryFocused)
                    .onSubmit(commitMaxHistory)
                    .onChange(of: maxHistoryDraft) { newValue in
                        let filtered = newValue.filter(\.isNumber)
                        if filtered != newValue {
                            maxHistoryDraft = filtered
                        }
                    }
                    .accessibilityIdentifier("settings-screenshot-max-history")
            }
            .onAppear(perform: syncMaxHistoryDraft)
            .onChange(of: maxHistoryCount) { _ in
                if !maxHistoryFocused {
                    syncMaxHistoryDraft()
                }
            }
            .onChange(of: maxHistoryFocused) { focused in
                if !focused {
                    commitMaxHistory()
                }
            }

            Stepper(value: $menuBarRecentCount, in: menuBarRecentRange) {
                Text("Show \(menuBarRecentCount) screenshots in menu bar", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-screenshot-menu-recent")
            .onChange(of: menuBarRecentCount) { newValue in
                let clamped = min(max(newValue, menuBarRecentRange.lowerBound), menuBarRecentRange.upperBound)
                if clamped != newValue {
                    menuBarRecentCount = clamped
                }
            }
        } header: {
            Text("Screenshots", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "Older screenshots beyond the remember limit are removed automatically.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
        }
    }

    private func syncMaxHistoryDraft() {
        maxHistoryDraft = "\(maxHistoryCount)"
    }

    private func commitMaxHistory() {
        let digits = maxHistoryDraft.filter(\.isNumber)
        let parsed = Int(digits) ?? maxHistoryCount
        let clamped = min(max(parsed, maxHistoryRange.lowerBound), maxHistoryRange.upperBound)
        let changed = clamped != maxHistoryCount
        maxHistoryCount = clamped
        maxHistoryDraft = "\(clamped)"
        if changed {
            onLimitsChanged?()
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
                Text("No apps ignored", bundle: BuddyL10n.bundle)
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
                        .accessibilityLabel(Text("Stop ignoring \(app.displayName)", bundle: BuddyL10n.bundle))
                        .accessibilityIdentifier("settings-ignore-remove-\(app.bundleIdentifier)")
                    }
                }
            }

            Button {
                addApp()
            } label: {
                Text("Add App…", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-ignore-add-app")
        } header: {
            Text("Ignored Apps", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "Copies made while these apps are frontmost are not saved to Clipboard Buddy history.",
                bundle: BuddyL10n.bundle
            )
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
        panel.message = BuddyL10n.string("Choose apps whose clipboard copies should be ignored")
        panel.prompt = BuddyL10n.string("Ignore")
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

/// Paint Buddy: history limits for colors.
public struct PaintHistorySettingsSection: View {
    @AppStorage(BuddySettingsKey.paintMaxHistoryCount) private var maxHistoryCount =
        PaintColorSettings.defaultMaxHistoryCount
    @AppStorage(BuddySettingsKey.paintMenuBarRecentCount) private var menuBarRecentCount =
        PaintColorSettings.defaultMenuBarRecentCount
    @AppStorage(BuddySettingsKey.paintFloatingPanelOnLaunch) private var floatingOnLaunch = false
    @AppStorage(BuddySettingsKey.paintFloatingGridCellSize) private var gridCellSize =
        PaintColorSettings.defaultFloatingGridCellSize

    private let onLimitsChanged: (() -> Void)?

    public init(onLimitsChanged: (() -> Void)? = nil) {
        self.onLimitsChanged = onLimitsChanged
    }

    public var body: some View {
        Section {
            Stepper(value: $maxHistoryCount, in: 10...2000, step: 10) {
                Text("Remember \(maxHistoryCount) colors", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-paint-max-history")
            .onChange(of: maxHistoryCount) { _ in onLimitsChanged?() }

            Stepper(value: $menuBarRecentCount, in: 1...50) {
                Text("Show \(menuBarRecentCount) colors in menu bar", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-paint-menu-recent")

            Toggle(isOn: $floatingOnLaunch) {
                Text("Open floating palette on launch", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-paint-floating-on-launch")

            Stepper(
                value: $gridCellSize,
                in: PaintColorSettings.minFloatingGridCellSize...PaintColorSettings.maxFloatingGridCellSize,
                step: 8
            ) {
                Text("Floating swatch size: \(gridCellSize) pt", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-paint-grid-cell-size")
        } header: {
            Text("Colors", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "Older colors beyond the remember limit are removed automatically.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
        }
    }
}

/// Paint Buddy: which clipboard formats to save and preferred copy format.
public struct PaintFormatSettingsSection: View {
    @AppStorage(BuddySettingsKey.paintCaptureHex) private var captureHex = true
    @AppStorage(BuddySettingsKey.paintCaptureRGB) private var captureRGB = true
    @AppStorage(BuddySettingsKey.paintCaptureRGBA) private var captureRGBA = true
    @AppStorage(BuddySettingsKey.paintCaptureNamed) private var captureNamed = true
    @AppStorage(BuddySettingsKey.paintCaptureTuple) private var captureTuple = true
    @AppStorage(BuddySettingsKey.paintCopyFormat) private var copyFormatRaw = PaintCopyFormat.hex.rawValue

    public init() {}

    public var body: some View {
        Section {
            Toggle(isOn: $captureHex) {
                Text("Save hex (#RRGGBB)", bundle: BuddyL10n.bundle)
            }
            Toggle(isOn: $captureRGB) {
                Text("Save rgb(...)", bundle: BuddyL10n.bundle)
            }
            Toggle(isOn: $captureRGBA) {
                Text("Save rgba(...)", bundle: BuddyL10n.bundle)
            }
            Toggle(isOn: $captureNamed) {
                Text("Save named colors (red, blue…)", bundle: BuddyL10n.bundle)
            }
            Toggle(isOn: $captureTuple) {
                Text("Save tuples (0, 0, 0)", bundle: BuddyL10n.bundle)
            }
        } header: {
            Text("Clipboard Capture", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "Only enabled formats are added to history when you copy a color.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
        }

        Section {
            Picker(selection: $copyFormatRaw) {
                Text("Hex (#RRGGBB)", bundle: BuddyL10n.bundle).tag(PaintCopyFormat.hex.rawValue)
                Text("Hex without # (RRGGBB)", bundle: BuddyL10n.bundle).tag(PaintCopyFormat.hexPlain.rawValue)
                Text("RGB", bundle: BuddyL10n.bundle).tag(PaintCopyFormat.rgb.rawValue)
                Text("RGBA", bundle: BuddyL10n.bundle).tag(PaintCopyFormat.rgba.rawValue)
            } label: {
                Text("Copy as", bundle: BuddyL10n.bundle)
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("settings-paint-copy-format")
        } header: {
            Text("Preferred Format", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "Used when you click a color in history or pick from the color panel. Also controls how colors are shown in lists.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
        }
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

    private var localizedNoun: String {
        BuddyL10n.string(key: itemNoun)
    }

    public var body: some View {
        Section {
            Button(role: .destructive) {
                confirm = true
            } label: {
                Text("Erase All History…", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-erase-all-history")
        } header: {
            Text("History", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "Removes all saved \(localizedNoun) from this Mac. This cannot be undone.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
        }
        .confirmationDialog(
            Text("Erase all \(localizedNoun)?", bundle: BuddyL10n.bundle),
            isPresented: $confirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                onClear()
            } label: {
                Text("Erase All", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-erase-all-confirm")
            Button(role: .cancel) {} label: {
                Text("Cancel", bundle: BuddyL10n.bundle)
            }
        } message: {
            Text("This cannot be undone.", bundle: BuddyL10n.bundle)
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

    private var localizedNoun: String {
        BuddyL10n.string(key: itemNoun)
    }

    public var body: some View {
        Group {
            switch style {
            case .menuBar:
                Button(role: .destructive) {
                    confirmEraseWithAlert()
                } label: {
                    Label {
                        Text("Erase All History…", bundle: BuddyL10n.bundle)
                    } icon: {
                        Image(systemName: "trash")
                    }
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
                .help(Text("Erase all history", bundle: BuddyL10n.bundle))
                .confirmationDialog(
                    Text("Erase all \(localizedNoun)?", bundle: BuddyL10n.bundle),
                    isPresented: $confirm,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) {
                        onClear()
                    } label: {
                        Text("Erase All", bundle: BuddyL10n.bundle)
                    }
                    .accessibilityIdentifier("erase-all-history-confirm")
                    Button(role: .cancel) {} label: {
                        Text("Cancel", bundle: BuddyL10n.bundle)
                    }
                } message: {
                    Text("This cannot be undone.", bundle: BuddyL10n.bundle)
                }
            }
        }
        .accessibilityIdentifier("erase-all-history")
        .accessibilityLabel(Text("Erase all history", bundle: BuddyL10n.bundle))
    }

    private func confirmEraseWithAlert() {
        let alert = NSAlert()
        alert.messageText = BuddyL10n.string("Erase all \(localizedNoun)?")
        alert.informativeText = BuddyL10n.string("This cannot be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: BuddyL10n.string("Erase All"))
        alert.addButton(withTitle: BuddyL10n.string("Cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            onClear()
        }
    }
}
