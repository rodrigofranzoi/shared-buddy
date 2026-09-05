import SwiftUI
import BuddyCore
import BuddyLocalization

public struct TagChip: View {
    public let tag: ContentTag

    public init(tag: ContentTag) {
        self.tag = tag
    }

    public var body: some View {
        Text(tag.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityLabel(Text("Tag: \(tag.rawValue)"))
    }

    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
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
                Button(action: onReveal) {
                    Label("Reveal", systemImage: "eye.slash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Hidden sensitive content")
                .accessibilityHint("Double tap to reveal")
            }
        }
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.buddyBody)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.buddyCaption)
                    .foregroundStyle(.secondary)
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

public extension Font {
    static var buddyBody: Font { .body }
    static var buddyCaption: Font { .caption }
}

public struct BuddyListChrome<Content: View>: View {
    @Binding public var query: String
    public let content: Content

    public init(query: Binding<String>, @ViewBuilder content: () -> Content) {
        self._query = query
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 12) {
            BuddySearchField(text: $query)
            content
        }
        .padding()
        .environment(\.layoutDirection, BuddyLocaleRuntime.isRTL ? .rightToLeft : .leftToRight)
    }
}
