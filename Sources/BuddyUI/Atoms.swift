import SwiftUI

// MARK: - Atoms

public struct BuddyText: View {
    public enum Style {
        case title, body, caption, label
    }

    private let text: String
    private let style: Style
    private let secondary: Bool

    public init(_ text: String, style: Style = .body, secondary: Bool = false) {
        self.text = text
        self.style = style
        self.secondary = secondary
    }

    public var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(secondary ? BuddyTheme.BuddyColor.textSecondary : BuddyTheme.BuddyColor.textPrimary)
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
    private let accessibilityLabel: String

    public init(systemName: String, accessibilityLabel: String) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(BuddyTheme.BuddyColor.textPrimary)
            .accessibilityLabel(accessibilityLabel)
    }
}

public struct BuddyButton: View {
    public enum Kind {
        case primary, secondary, ghost, danger
    }

    private let title: String
    private let systemImage: String?
    private let kind: Kind
    private let action: () -> Void

    public init(
        _ title: String,
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
                Text(title)
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
        .accessibilityLabel(title)
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
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(BuddyTheme.Typography.label)
            .padding(.horizontal, BuddyTheme.Spacing.sm)
            .padding(.vertical, BuddyTheme.Spacing.xxs)
            .background(BuddyTheme.BuddyColor.accent.opacity(0.2))
            .foregroundStyle(BuddyTheme.BuddyColor.accent)
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}

public struct BuddyDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .background(BuddyTheme.BuddyColor.border)
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
