import SwiftUI
import AppKit
import BuddyCore
import BuddyLocalization

// MARK: - Molecules (compose atoms / tokens)

public struct TagChip: View {
    public let tag: ContentTag

    public init(tag: ContentTag) {
        self.tag = tag
    }

    public var body: some View {
        Text(ContentTagger.displayName(for: tag))
            .font(BuddyTheme.Typography.label)
            .padding(.horizontal, BuddyTheme.Spacing.sm)
            .padding(.vertical, BuddyTheme.Spacing.xs)
            .background(chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: BuddyTheme.Radius.md, style: .continuous))
            .accessibilityLabel(ContentTagger.displayName(for: tag))
    }

    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: BuddyTheme.Radius.md, style: .continuous)
            .fill(BuddyTheme.BuddyColor.chipFill)
            .overlay(
                RoundedRectangle(cornerRadius: BuddyTheme.Radius.md, style: .continuous)
                    .strokeBorder(BuddyTheme.BuddyColor.chipBorder, lineWidth: 1)
            )
    }
}

public struct SensitiveBlurView<Content: View>: View {
    public let isHidden: Bool
    public let content: Content
    public let onReveal: () -> Void

    public init(isHidden: Bool, onReveal: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isHidden = isHidden
        self.onReveal = onReveal
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .blur(radius: isHidden ? 10 : 0)
                .allowsHitTesting(!isHidden)
            if isHidden {
                BuddyButton("Reveal", systemImage: "eye.slash", kind: .secondary, action: onReveal)
                    .accessibilityLabel(Text("Hidden sensitive content", bundle: BuddyL10n.bundle))
                    .accessibilityHint(Text("Double tap to reveal", bundle: BuddyL10n.bundle))
            }
        }
        .animation(.easeInOut(duration: BuddyTheme.Duration.value(BuddyTheme.Duration.quick)), value: isHidden)
    }
}

public struct BuddySearchField: View {
    @Binding public var text: String
    public var placeholderKey: LocalizedStringKey

    public init(text: Binding<String>, placeholder: LocalizedStringKey = "Search") {
        self._text = text
        self.placeholderKey = placeholder
    }

    public var body: some View {
        TextField(text: $text) {
            Text(placeholderKey, bundle: BuddyL10n.bundle)
        }
        .textFieldStyle(.roundedBorder)
        .font(BuddyTheme.Typography.body)
        .accessibilityLabel(Text(placeholderKey, bundle: BuddyL10n.bundle))
    }
}

public struct MenuBarRow: View {
    public let title: String
    public let subtitle: String
    public let thumbnail: Image?
    public let thumbnailBlur: CGFloat
    public let colorSwatch: Color?
    public let openAction: (() -> Void)?
    public let copyAction: (() -> Void)?
    public let showsSeparator: Bool
    /// Optional shortcut hint shown beside the row (e.g. `⌘1`).
    public let shortcutHint: String?
    public let action: () -> Void

    @State private var rowJustCopied = false
    @State private var buttonJustCopied = false

    private static let mediaSlotWidth: CGFloat = 28
    private static let mediaSlotHeight: CGFloat = 22
    private static let shortcutSlotWidth: CGFloat = 28
    private static let trailingButtonWidth: CGFloat = 18

    public init(
        title: String,
        subtitle: String = "",
        thumbnail: Image? = nil,
        thumbnailBlur: CGFloat = 0,
        colorSwatch: Color? = nil,
        openAction: (() -> Void)? = nil,
        copyAction: (() -> Void)? = nil,
        showsSeparator: Bool = true,
        shortcutHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.thumbnail = thumbnail
        self.thumbnailBlur = thumbnailBlur
        self.colorSwatch = colorSwatch
        self.openAction = openAction
        self.copyAction = copyAction
        self.showsSeparator = showsSeparator
        self.shortcutHint = shortcutHint
        self.action = action
    }

    public var body: some View {
        HStack(spacing: BuddyTheme.Spacing.sm) {
            leadingIcon

            Button {
                action()
                // Color rows: flash “Copied” on the row itself (not the copy button).
                if colorSwatch != nil {
                    rowJustCopied = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        rowJustCopied = false
                    }
                }
            } label: {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityValue(rowJustCopied ? Text("Copied", bundle: BuddyL10n.bundle) : Text(verbatim: ""))

            shortcutSlot
            copySlot
        }
        .padding(.vertical, BuddyTheme.Spacing.sm)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                BuddyDivider()
            }
        }
    }

    private var accessibilityTitle: Text {
        if subtitle.isEmpty {
            return Text(verbatim: title)
        }
        return Text(verbatim: "\(title), \(subtitle)")
    }

    @ViewBuilder
    private var leadingIcon: some View {
        Group {
            if let thumbnail {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.mediaSlotWidth, height: Self.mediaSlotHeight)
                    .clipped()
                    .cornerRadius(4)
                    .blur(radius: thumbnailBlur)
                    .accessibilityHidden(true)
            } else if let colorSwatch {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(colorSwatch)
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    if rowJustCopied {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                }
                .accessibilityHidden(true)
            } else if let openAction {
                Button(action: openAction) {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BuddyTheme.BuddyColor.accent)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Open link", bundle: BuddyL10n.bundle))
                .help(Text("Open link", bundle: BuddyL10n.bundle))
            } else {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BuddyTheme.BuddyColor.textSecondary)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Self.mediaSlotWidth, height: Self.mediaSlotHeight, alignment: .center)
    }

    @ViewBuilder
    private var titleBlock: some View {
        if subtitle.isEmpty {
            BuddyText(verbatim: title, style: .body)
                .lineLimit(1)
        } else {
            VStack(alignment: .leading, spacing: BuddyTheme.Spacing.xxs) {
                BuddyText(verbatim: title, style: .body)
                    .lineLimit(1)
                BuddyText(verbatim: subtitle, style: .caption, secondary: true)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var shortcutSlot: some View {
        Group {
            if let shortcutHint, !shortcutHint.isEmpty {
                Text(verbatim: shortcutHint)
                    .font(.caption2.monospaced())
                    .foregroundStyle(BuddyTheme.BuddyColor.textSecondary)
                    .accessibilityHidden(true)
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Self.shortcutSlotWidth, alignment: .trailing)
    }

    @ViewBuilder
    private var copySlot: some View {
        Group {
            if let copyAction {
                Button {
                    copyAction()
                    buttonJustCopied = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        buttonJustCopied = false
                    }
                } label: {
                    Image(systemName: buttonJustCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundStyle(buttonJustCopied ? BuddyTheme.BuddyColor.success : Color.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(buttonJustCopied ? Text("Copied", bundle: BuddyL10n.bundle) : Text("Copy", bundle: BuddyL10n.bundle))
                .help(buttonJustCopied ? Text("Copied", bundle: BuddyL10n.bundle) : Text("Copy to clipboard", bundle: BuddyL10n.bundle))
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Self.trailingButtonWidth, height: Self.trailingButtonWidth)
    }
}

/// Row for a detected color (swatch) or URL (Open) token in Tools lists.
public struct DetectedContentTokenRow: View {
    public let token: DetectedContentToken
    public let onCopy: (String) -> Void
    public let onOpen: ((URL) -> Void)?
    public let showsSeparator: Bool

    public init(
        token: DetectedContentToken,
        showsSeparator: Bool = true,
        onCopy: @escaping (String) -> Void,
        onOpen: ((URL) -> Void)? = { NSWorkspace.shared.open($0) }
    ) {
        self.token = token
        self.showsSeparator = showsSeparator
        self.onCopy = onCopy
        self.onOpen = onOpen
    }

    public var body: some View {
        HStack(spacing: BuddyTheme.Spacing.sm) {
            if token.kind == .color {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: token.nsColor ?? .black))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }

            Text(token.raw)
                .font(.caption.monospaced())
                .lineLimit(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if token.kind == .url, let url = token.openableURL, let onOpen {
                Button {
                    onOpen(url)
                } label: {
                    Label { Text("Open", bundle: BuddyL10n.bundle) } icon: { Image(systemName: "safari") }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(Text("Open link", bundle: BuddyL10n.bundle))
            }

            Button {
                onCopy(token.raw)
            } label: {
                Label { Text("Copy", bundle: BuddyL10n.bundle) } icon: { Image(systemName: "doc.on.doc") }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(Text("Copy to clipboard", bundle: BuddyL10n.bundle))
        }
        .padding(.vertical, BuddyTheme.Spacing.sm)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                BuddyDivider()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(token.kind == .color ? Text("Detected color", bundle: BuddyL10n.bundle) : Text("Detected link", bundle: BuddyL10n.bundle))
        .accessibilityValue(token.raw)
    }
}

public struct BuddyListChrome<Content: View>: View {
    @Binding public var query: String
    public let content: Content

    public init(query: Binding<String>, @ViewBuilder content: () -> Content) {
        self._query = query
        self.content = content()
    }

    public var body: some View {
        BuddyVStack(spacing: BuddyTheme.Spacing.md) {
            BuddySearchField(text: $query)
            content
        }
        .padding(BuddyTheme.Spacing.lg)
        .background(BuddyTheme.BuddyColor.background)
        .environment(\.layoutDirection, BuddyLocaleRuntime.isRTL ? .rightToLeft : .leftToRight)
    }
}

/// Toolbar popover shown when sexual / pornographic content is blocked from copy/import.
public struct ContentBlockedAlert: View {
    public var autoDismissSeconds: TimeInterval
    public var onDismiss: (_ neverShowAgain: Bool) -> Void

    @State private var neverShowAgain = false
    @State private var didDismiss = false

    public init(
        autoDismissSeconds: TimeInterval = 5,
        onDismiss: @escaping (_ neverShowAgain: Bool) -> Void
    ) {
        self.autoDismissSeconds = autoDismissSeconds
        self.onDismiss = onDismiss
    }

    public var body: some View {
        BuddyVStack(spacing: BuddyTheme.Spacing.md) {
            HStack(alignment: .top, spacing: BuddyTheme.Spacing.sm) {
                BuddyIcon(systemName: "exclamationmark.shield.fill", accessibilityLabel: "Blocked content")
                BuddyVStack(spacing: BuddyTheme.Spacing.xs) {
                    BuddyText("Content blocked", style: .title)
                    BuddyText(
                        "We can’t copy this kind of content. Pornography and sexual material aren’t allowed.",
                        style: .body,
                        secondary: true
                    )
                }
            }

            Toggle(isOn: $neverShowAgain) {
                Text("Never show again", bundle: BuddyL10n.bundle)
            }
            .toggleStyle(.checkbox)
            .font(BuddyTheme.Typography.caption)
            .accessibilityIdentifier("content-blocked-never-show")

            HStack {
                Spacer(minLength: 0)
                BuddyButton("Dismiss", kind: .secondary) {
                    finish(neverShowAgain: neverShowAgain)
                }
                .accessibilityIdentifier("content-blocked-dismiss")
            }
        }
        .padding(BuddyTheme.Spacing.lg)
        .frame(width: 280)
        .background(BuddyTheme.BuddyColor.background)
        .onAppear { scheduleAutoDismiss() }
        .accessibilityIdentifier("content-blocked-alert")
    }

    private func scheduleAutoDismiss() {
        let seconds = autoDismissSeconds
        Task { @MainActor in
            let nanos = UInt64(max(seconds, 0.5) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            finish(neverShowAgain: neverShowAgain)
        }
    }

    private func finish(neverShowAgain: Bool) {
        guard !didDismiss else { return }
        didDismiss = true
        onDismiss(neverShowAgain)
    }
}

/// Settings for password-locking sensitive previews (Privacy tab).
public struct SensitivePrivacySettingsSection: View {
    @AppStorage(BuddySettingsKey.requireAuthSensitiveContent) private var requireAuth = false
    @AppStorage(BuddySettingsKey.protectedContentTags) private var protectedRaw: String = ""

    public init() {}

    public var body: some View {
        Section {
            Toggle(isOn: requireAuthBinding) {
                Text("Ask for password or Touch ID to view sensitive content", bundle: BuddyL10n.bundle)
            }
            .accessibilityIdentifier("settings-require-auth-sensitive")

            if requireAuth {
                Text(
                    "Matching items stay blurred until unlocked, then remain visible for 10 minutes.",
                    bundle: BuddyL10n.bundle
                )
                .font(BuddyTheme.Typography.caption)
                .foregroundStyle(.secondary)

                Text("What is sensitive content", bundle: BuddyL10n.bundle)
                    .font(BuddyTheme.Typography.label)
                    .padding(.top, 4)

                Text(
                    "These types stay hidden until unlocked with password or Touch ID.",
                    bundle: BuddyL10n.bundle
                )
                .font(BuddyTheme.Typography.caption)
                .foregroundStyle(.secondary)

                ForEach(ContentTagger.autoBlurSelectableTags, id: \.self) { tag in
                    Toggle(ContentTagger.displayName(for: tag), isOn: protectedBinding(for: tag))
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("settings-protected-\(tag.rawValue)")
                }
            }
        } header: {
            Text("Sensitive content", bundle: BuddyL10n.bundle)
        }
        .onAppear { syncProtectedStorage() }
    }

    private var requireAuthBinding: Binding<Bool> {
        Binding(
            get: { requireAuth },
            set: { newValue in
                if newValue {
                    requireAuth = true
                    return
                }
                // Turning off must confirm with password / Touch ID (even if already unlocked).
                SensitiveUnlockSession.shared.authenticate(
                    reason: BuddyL10n.string("Disable password or Touch ID protection")
                ) { success in
                    guard success else { return }
                    requireAuth = false
                    SensitiveUnlockSession.shared.lock()
                }
            }
        )
    }

    private func protectedBinding(for tag: ContentTag) -> Binding<Bool> {
        Binding(
            get: {
                _ = protectedRaw
                return SensitivePrivacySettings.isProtected(tag)
            },
            set: { newValue in
                SensitivePrivacySettings.setProtected(newValue, for: tag)
                syncProtectedStorage()
            }
        )
    }

    private func syncProtectedStorage() {
        protectedRaw = SensitivePrivacySettings.protectedTags.map(\.rawValue).sorted().joined(separator: ",")
    }
}

/// Auto-blur detection types (General tab in Capture Buddy).
public struct AutoBlurSettingsSection: View {
    @AppStorage(BuddySettingsKey.autoBlurContentTags) private var autoBlurRaw: String = ""

    public init() {}

    public var body: some View {
        Section {
            Text(
                "These types are detected and blurred in the screenshot editor.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
            .foregroundStyle(.secondary)

            ForEach(ContentTagger.autoBlurSelectableTags, id: \.self) { tag in
                Toggle(ContentTagger.displayName(for: tag), isOn: autoBlurBinding(for: tag))
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("settings-auto-blur-\(tag.rawValue)")
            }
        } header: {
            Text("Auto-blur", bundle: BuddyL10n.bundle)
        }
        .onAppear { syncAutoBlurStorage() }
    }

    private func autoBlurBinding(for tag: ContentTag) -> Binding<Bool> {
        Binding(
            get: {
                _ = autoBlurRaw
                return SensitivePrivacySettings.isAutoBlurEnabled(for: tag)
            },
            set: { newValue in
                SensitivePrivacySettings.setAutoBlurEnabled(newValue, for: tag)
                syncAutoBlurStorage()
            }
        )
    }

    private func syncAutoBlurStorage() {
        autoBlurRaw = SensitivePrivacySettings.autoBlurTags.map(\.rawValue).sorted().joined(separator: ",")
    }
}

#if os(macOS)
/// Opens the app's SwiftUI `Settings` scene.
/// Prefer ``BuddyOpenSettingsButton`` / ``BuddyDeferredOpenSettingsButton`` — `showSettingsWindow:`
/// is unreliable on macOS 14+.
public func buddyOpenAppSettings() {
    NSApp.activate(ignoringOtherApps: true)
    if #available(macOS 13.0, *) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

/// Toolbar / control that opens Settings via `SettingsLink` (macOS 14+) with a sendAction fallback.
public struct BuddyOpenSettingsButton<Label: View>: View {
    private let helpKey: LocalizedStringKey
    private let accessibilityLabelKey: LocalizedStringKey
    private let accessibilityId: String?
    @ViewBuilder private let label: () -> Label

    public init(
        help: LocalizedStringKey = "Settings",
        accessibilityLabel: LocalizedStringKey = "Settings",
        accessibilityIdentifier: String? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.helpKey = help
        self.accessibilityLabelKey = accessibilityLabel
        self.accessibilityId = accessibilityIdentifier
        self.label = label
    }

    public var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                SettingsLink(label: label)
            } else {
                Button(action: buddyOpenAppSettings, label: label)
            }
        }
        .help(Text(helpKey, bundle: BuddyL10n.bundle))
        .accessibilityLabel(Text(accessibilityLabelKey, bundle: BuddyL10n.bundle))
        .modifier(BuddyOptionalAccessibilityIdentifier(accessibilityId))
    }
}

private struct BuddyOptionalAccessibilityIdentifier: ViewModifier {
    let id: String?

    init(_ id: String?) {
        self.id = id
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

/// Gear-icon Settings control used across Buddy apps.
public struct BuddySettingsGearButton: View {
    private let helpKey: LocalizedStringKey
    private let accessibilityLabelKey: LocalizedStringKey
    private let accessibilityId: String?

    public init(
        help: LocalizedStringKey = "Settings",
        accessibilityLabel: LocalizedStringKey = "Settings",
        accessibilityIdentifier: String? = nil
    ) {
        self.helpKey = help
        self.accessibilityLabelKey = accessibilityLabel
        self.accessibilityId = accessibilityIdentifier
    }

    public var body: some View {
        BuddyOpenSettingsButton(
            help: helpKey,
            accessibilityLabel: accessibilityLabelKey,
            accessibilityIdentifier: accessibilityId
        ) {
            Image(systemName: "gearshape")
        }
    }
}

/// Opens Settings after an optional dismiss (e.g. closing a popover first).
@available(macOS 14.0, *)
public struct BuddyDeferredOpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    private let title: LocalizedStringKey
    private let beforeOpen: () -> Void

    public init(title: LocalizedStringKey, beforeOpen: @escaping () -> Void = {}) {
        self.title = title
        self.beforeOpen = beforeOpen
    }

    public var body: some View {
        Button {
            beforeOpen()
            DispatchQueue.main.async {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            // App-owned string (catalog in the host app main bundle).
            Text(title)
        }
    }
}
#endif

/// ⌘1…⌘9 / ⌘0 copy the 1st…10th item in the focused list (0 → 10th).
public struct BuddyDigitCopyShortcutsModifier: ViewModifier {
    public let itemCount: Int
    public let action: (Int) -> Void

    public init(itemCount: Int, action: @escaping (Int) -> Void) {
        self.itemCount = itemCount
        self.action = action
    }

    public func body(content: Content) -> some View {
        content.background(alignment: .topLeading) {
            ForEach(0..<min(max(itemCount, 0), 10), id: \.self) { index in
                Button {
                    action(index)
                } label: {
                    Color.clear
                        .frame(width: 1, height: 1)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(Self.keyEquivalent(for: index), modifiers: .command)
                .accessibilityHidden(true)
            }
        }
    }

    /// Index 0 → ⌘1 … index 8 → ⌘9, index 9 → ⌘0.
    public static func keyEquivalent(for index: Int) -> KeyEquivalent {
        let digit = index >= 9 ? 0 : index + 1
        return KeyEquivalent(Character(String(digit)))
    }

    /// Display hint for the same mapping (`⌘1` … `⌘0`).
    public static func hint(for index: Int) -> String {
        let digit = index >= 9 ? 0 : index + 1
        return "⌘\(digit)"
    }
}

public extension View {
    /// Registers ⌘1…⌘9 / ⌘0 to invoke `action` with a 0-based index (max 10 items).
    func buddyDigitCopyShortcuts(itemCount: Int, action: @escaping (Int) -> Void) -> some View {
        modifier(BuddyDigitCopyShortcutsModifier(itemCount: itemCount, action: action))
    }
}

// Back-compat font aliases used by apps
public extension Font {
    static var buddyBody: Font { BuddyTheme.Typography.body }
    static var buddyCaption: Font { BuddyTheme.Typography.caption }
}
