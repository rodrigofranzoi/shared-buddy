import SwiftUI
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
    public let action: () -> Void

    public init(title: String, subtitle: String, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: BuddyTheme.Spacing.xxs) {
                BuddyText(title, style: .body)
                    .lineLimit(1)
                BuddyText(subtitle, style: .caption, secondary: true)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
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

// Back-compat font aliases used by apps
public extension Font {
    static var buddyBody: Font { BuddyTheme.Typography.body }
    static var buddyCaption: Font { BuddyTheme.Typography.caption }
}
