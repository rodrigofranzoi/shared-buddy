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
        Text(tag.rawValue)
            .font(BuddyTheme.Typography.label)
            .padding(.horizontal, BuddyTheme.Spacing.sm)
            .padding(.vertical, BuddyTheme.Spacing.xs)
            .background(chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: BuddyTheme.Radius.md, style: .continuous))
            .accessibilityLabel(Text("Tag: \(tag.rawValue)"))
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
                    .accessibilityLabel("Hidden sensitive content")
                    .accessibilityHint("Double tap to reveal")
            }
        }
        .animation(.easeInOut(duration: BuddyTheme.Duration.value(BuddyTheme.Duration.quick)), value: isHidden)
    }
}

public struct BuddySearchField: View {
    @Binding public var text: String
    public var placeholder: String

    public init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .font(BuddyTheme.Typography.body)
            .accessibilityLabel(placeholder)
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
    public let action: () -> Void

    @State private var justCopied = false

    public init(
        title: String,
        subtitle: String,
        thumbnail: Image? = nil,
        thumbnailBlur: CGFloat = 0,
        colorSwatch: Color? = nil,
        openAction: (() -> Void)? = nil,
        copyAction: (() -> Void)? = nil,
        showsSeparator: Bool = true,
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
        self.action = action
    }

    public var body: some View {
        HStack(spacing: BuddyTheme.Spacing.sm) {
            Button(action: action) {
                HStack(spacing: BuddyTheme.Spacing.sm) {
                    if let thumbnail {
                        thumbnail
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 30)
                            .clipped()
                            .cornerRadius(4)
                            .blur(radius: thumbnailBlur)
                            .accessibilityHidden(true)
                    } else if let colorSwatch {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(colorSwatch)
                            .frame(width: 18, height: 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                            )
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: BuddyTheme.Spacing.xxs) {
                        BuddyText(title, style: .body)
                            .lineLimit(1)
                        BuddyText(subtitle, style: .caption, secondary: true)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(subtitle)")

            if let openAction {
                Button(action: openAction) {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open link")
                .help("Open link")
            }

            if let copyAction {
                Button {
                    copyAction()
                    justCopied = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        justCopied = false
                    }
                } label: {
                    Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundStyle(justCopied ? Color.green : Color.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(justCopied ? "Copied" : "Copy")
                .help(justCopied ? "Copied" : "Copy to clipboard")
            }
        }
        .padding(.vertical, BuddyTheme.Spacing.sm)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                BuddyDivider()
            }
        }
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
                    Label("Open", systemImage: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open link")
            }

            Button {
                onCopy(token.raw)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Copy to clipboard")
        }
        .padding(.vertical, BuddyTheme.Spacing.sm)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                BuddyDivider()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(token.kind == .color ? "Detected color" : "Detected link")
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

            Toggle("Never show again", isOn: $neverShowAgain)
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
        Section("Sensitive content") {
            Toggle("Ask for password or Touch ID to view sensitive content", isOn: $requireAuth)
                .accessibilityIdentifier("settings-require-auth-sensitive")

            if requireAuth {
                Text("Matching items stay blurred until unlocked, then remain visible for 10 minutes.")
                    .font(BuddyTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                Text("What is sensitive content")
                    .font(BuddyTheme.Typography.label)
                    .padding(.top, 4)

                Text("These types stay hidden until unlocked with password or Touch ID.")
                    .font(BuddyTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                ForEach(ContentTagger.autoBlurSelectableTags, id: \.self) { tag in
                    Toggle(ContentTagger.displayName(for: tag), isOn: protectedBinding(for: tag))
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("settings-protected-\(tag.rawValue)")
                }
            }
        }
        .onAppear { syncProtectedStorage() }
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

/// Auto-blur detection types (General tab in Screenshot Buddy).
public struct AutoBlurSettingsSection: View {
    @AppStorage(BuddySettingsKey.autoBlurContentTags) private var autoBlurRaw: String = ""

    public init() {}

    public var body: some View {
        Section("Auto-blur") {
            Text("These types are detected and blurred in the screenshot editor.")
                .font(BuddyTheme.Typography.caption)
                .foregroundStyle(.secondary)

            ForEach(ContentTagger.autoBlurSelectableTags, id: \.self) { tag in
                Toggle(ContentTagger.displayName(for: tag), isOn: autoBlurBinding(for: tag))
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("settings-auto-blur-\(tag.rawValue)")
            }
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
    private let helpText: String
    private let accessibilityLabelText: String
    private let accessibilityId: String?
    @ViewBuilder private let label: () -> Label

    public init(
        help: String = "Settings",
        accessibilityLabel: String = "Settings",
        accessibilityIdentifier: String? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.helpText = help
        self.accessibilityLabelText = accessibilityLabel
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
        .help(helpText)
        .accessibilityLabel(accessibilityLabelText)
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
    private let helpText: String
    private let accessibilityLabelText: String
    private let accessibilityId: String?

    public init(
        help: String = "Settings",
        accessibilityLabel: String = "Settings",
        accessibilityIdentifier: String? = nil
    ) {
        self.helpText = help
        self.accessibilityLabelText = accessibilityLabel
        self.accessibilityId = accessibilityIdentifier
    }

    public var body: some View {
        BuddyOpenSettingsButton(
            help: helpText,
            accessibilityLabel: accessibilityLabelText,
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
    private let title: String
    private let beforeOpen: () -> Void

    public init(title: String, beforeOpen: @escaping () -> Void = {}) {
        self.title = title
        self.beforeOpen = beforeOpen
    }

    public var body: some View {
        Button(title) {
            beforeOpen()
            DispatchQueue.main.async {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
#endif

// Back-compat font aliases used by apps
public extension Font {
    static var buddyBody: Font { BuddyTheme.Typography.body }
    static var buddyCaption: Font { BuddyTheme.Typography.caption }
}
