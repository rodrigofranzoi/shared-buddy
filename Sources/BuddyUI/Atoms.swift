import SwiftUI
import BuddyLocalization

// MARK: - Atoms

public struct BuddyText: View {
    public enum Style {
        case title, body, caption, label
    }

    private enum Content {
        case localized(LocalizedStringKey)
        case verbatim(String)
    }

    private let content: Content
    private let style: Style
    private let secondary: Bool

    public init(_ key: LocalizedStringKey, style: Style = .body, secondary: Bool = false) {
        self.content = .localized(key)
        self.style = style
        self.secondary = secondary
    }

    public init(verbatim text: String, style: Style = .body, secondary: Bool = false) {
        self.content = .verbatim(text)
        self.style = style
        self.secondary = secondary
    }

    public var body: some View {
        textView
            .font(font)
            .foregroundStyle(secondary ? BuddyTheme.BuddyColor.textSecondary : BuddyTheme.BuddyColor.textPrimary)
    }

    @ViewBuilder
    private var textView: some View {
        switch content {
        case .localized(let key):
            Text(key, bundle: BuddyL10n.bundle)
        case .verbatim(let text):
            Text(verbatim: text)
        }
    }

    private var font: Font {
        switch style {
        case .title: return BuddyTheme.Typography.title
        case .body: return BuddyTheme.Typography.body
        case .caption: return BuddyTheme.Typography.caption
        case .label: return BuddyTheme.Typography.label
        }
    }
}

public struct BuddyIcon: View {
    private let systemName: String
    private let accessibilityLabelKey: LocalizedStringKey

    public init(systemName: String, accessibilityLabel: LocalizedStringKey) {
        self.systemName = systemName
        self.accessibilityLabelKey = accessibilityLabel
    }

    public var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(BuddyTheme.BuddyColor.textPrimary)
            .accessibilityLabel(Text(accessibilityLabelKey, bundle: BuddyL10n.bundle))
    }
}

public struct BuddyButton: View {
    public enum Kind {
        case primary, secondary, ghost, danger
    }

    private let title: LocalizedStringKey
    private let systemImage: String?
    private let kind: Kind
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        kind: Kind = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: BuddyTheme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title, bundle: BuddyL10n.bundle)
            }
            .font(BuddyTheme.Typography.body)
            .padding(.horizontal, BuddyTheme.Spacing.md)
            .padding(.vertical, BuddyTheme.Spacing.sm)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: BuddyTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BuddyTheme.Radius.md, style: .continuous)
                    .strokeBorder(border, lineWidth: kind == .secondary || kind == .ghost ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title, bundle: BuddyL10n.bundle))
    }

    private var background: Color {
        switch kind {
        case .primary: return BuddyTheme.BuddyColor.accent.opacity(0.85)
        case .secondary, .ghost: return .clear
        case .danger: return BuddyTheme.BuddyColor.danger.opacity(0.9)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary, .danger: return .white
        case .secondary, .ghost: return BuddyTheme.BuddyColor.textPrimary
        }
    }

    private var border: Color {
        switch kind {
        case .secondary: return BuddyTheme.BuddyColor.border
        case .ghost: return .clear
        default: return .clear
        }
    }
}

public struct BuddyBadge: View {
    private let key: LocalizedStringKey

    public init(_ key: LocalizedStringKey) {
        self.key = key
    }

    public var body: some View {
        Text(key, bundle: BuddyL10n.bundle)
            .font(BuddyTheme.Typography.label)
            .padding(.horizontal, BuddyTheme.Spacing.sm)
            .padding(.vertical, BuddyTheme.Spacing.xxs)
            .background(BuddyTheme.BuddyColor.accent.opacity(0.2))
            .foregroundStyle(BuddyTheme.BuddyColor.accent)
            .clipShape(Capsule())
            .accessibilityLabel(Text(key, bundle: BuddyL10n.bundle))
    }
}

public struct BuddyDivider: View {
    private let opacity: Double

    public init(opacity: Double = 0.4) {
        self.opacity = opacity
    }

    public var body: some View {
        Divider()
            .overlay(BuddyTheme.BuddyColor.border.opacity(opacity))
            .accessibilityHidden(true)
    }
}

public struct BuddyVStack<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = BuddyTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
    }
}
