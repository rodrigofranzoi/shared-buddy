import AppKit
import SwiftUI
import BuddyCore

// MARK: - Sidebar settings chrome

/// A settings sidebar destination (Appearance / Preferences / Privacy / …).
public struct BuddySettingsItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }

    public static let appearance = BuddySettingsItem(
        id: "appearance",
        title: "Appearance",
        systemImage: "paintpalette"
    )
    public static let preferences = BuddySettingsItem(
        id: "preferences",
        title: "Preferences",
        systemImage: "gearshape"
    )
    public static let privacy = BuddySettingsItem(
        id: "privacy",
        title: "Privacy",
        systemImage: "hand.raised"
    )
    public static let account = BuddySettingsItem(
        id: "account",
        title: "Account",
        systemImage: "envelope"
    )
}

/// Left-menu Settings shell: sidebar list + detail form content.
public struct BuddySettingsSidebarView<Content: View>: View {
    private let brand: BuddyBrand
    private let items: [BuddySettingsItem]
    private let usesSettingsWindowSize: Bool
    private let content: (BuddySettingsItem) -> Content

    @State private var selection: String

    /// - Parameter usesSettingsWindowSize: Prefer `true` for `Settings` scenes; `false` when embedded in a main window.
    public init(
        brand: BuddyBrand,
        items: [BuddySettingsItem],
        usesSettingsWindowSize: Bool = true,
        initialSelection: BuddySettingsItem? = nil,
        @ViewBuilder content: @escaping (BuddySettingsItem) -> Content
    ) {
        self.brand = brand
        self.items = items
        self.usesSettingsWindowSize = usesSettingsWindowSize
        self.content = content
        let fallback = items.first?.id ?? BuddySettingsItem.appearance.id
        _selection = State(initialValue: initialSelection?.id ?? fallback)
    }

    public var body: some View {
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(items) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item.id)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 180)
            .accessibilityIdentifier("settings-sidebar")

            Divider()

            Group {
                if let item = items.first(where: { $0.id == selection }) {
                    Form {
                        content(item)
                    }
                    .formStyle(.grouped)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityIdentifier("settings-detail-\(item.id)")
                } else {
                    Text("Select a category")
                        .foregroundStyle(BuddyTheme.BuddyColor.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(
            minWidth: usesSettingsWindowSize ? 620 : nil,
            idealWidth: usesSettingsWindowSize ? 640 : nil,
            minHeight: usesSettingsWindowSize ? 440 : nil,
            idealHeight: usesSettingsWindowSize ? 480 : nil
        )
        .buddyAppearance(brand: brand)
    }
}

// MARK: - Legacy top-tab chrome (kept for compatibility)

/// Top-tab Settings chrome used by Buddy apps (General / Privacy / …).
@available(*, deprecated, message: "Use BuddySettingsSidebarView instead.")
public struct BuddySettingsTabView<Content: View>: View {
    private let usesSettingsWindowSize: Bool
    private let content: Content

    /// - Parameter usesSettingsWindowSize: Prefer `true` for `Settings` scenes; `false` when embedded in a main window.
    public init(usesSettingsWindowSize: Bool = true, @ViewBuilder content: () -> Content) {
        self.usesSettingsWindowSize = usesSettingsWindowSize
        self.content = content()
    }

    public var body: some View {
        TabView {
            content
        }
        .frame(
            minWidth: usesSettingsWindowSize ? 460 : nil,
            idealWidth: usesSettingsWindowSize ? 460 : nil,
            minHeight: usesSettingsWindowSize ? 520 : nil,
            idealHeight: usesSettingsWindowSize ? 520 : nil
        )
    }
}

/// Grouped form pane for one Settings tab.
@available(*, deprecated, message: "Use BuddySettingsSidebarView with BuddySettingsItem instead.")
public struct BuddySettingsPane<Content: View>: View {
    private let title: String
    private let systemImage: String
    private let content: Content

    public init(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    public var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .tabItem {
            Label(title, systemImage: systemImage)
        }
    }
}

// MARK: - Appearance

/// Appearance controls: light/dark/system + theme accent color.
public struct BuddyAppearanceSettingsSection: View {
    private let brand: BuddyBrand

    @AppStorage(BuddySettingsKey.appearanceColorScheme) private var colorSchemeRaw: String =
        BuddyAppearanceSettings.ColorSchemePreference.system.rawValue
    @AppStorage(BuddySettingsKey.appearanceAccentHex) private var accentHexRaw: String = ""

    public init(brand: BuddyBrand) {
        self.brand = brand
    }

    public var body: some View {
        Section("Mode") {
            Picker("Appearance", selection: $colorSchemeRaw) {
                ForEach(BuddyAppearanceSettings.ColorSchemePreference.allCases, id: \.rawValue) { preference in
                    Text(preference.title).tag(preference.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("settings-appearance-mode")
            .onChange(of: colorSchemeRaw) { _ in
                BuddyAppearanceSettings.applyAppKitAppearance()
            }
        }

        Section {
            HStack(spacing: BuddyTheme.Spacing.md) {
                ForEach(BuddyAppearanceSettings.accentPresets, id: \.self) { hex in
                    AccentSwatchButton(
                        hex: hex,
                        isSelected: resolvedAccentHex.compare(hex, options: .caseInsensitive) == .orderedSame
                    ) {
                        accentHexRaw = hex
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, BuddyTheme.Spacing.xxs)

            ColorPicker(
                "Custom color",
                selection: Binding(
                    get: { Color(nsColor: BuddyAppearanceSettings.accentNSColor(for: brand)) },
                    set: { newColor in
                        accentHexRaw = EditorRedactionSettings.hex(from: NSColor(newColor))
                    }
                ),
                supportsOpacity: false
            )
            .accessibilityIdentifier("settings-appearance-custom-color")

            if !isUsingBrandDefault {
                Button("Reset to \(brand.displayName) default") {
                    accentHexRaw = brand.defaultAccentHex
                }
                .accessibilityIdentifier("settings-appearance-reset-accent")
            }
        } header: {
            Text("Theme color")
        } footer: {
            Text("Default for \(brand.displayName) is \(brand.defaultAccentHex).")
                .font(BuddyTheme.Typography.caption)
        }
        .onAppear {
            if accentHexRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                accentHexRaw = brand.defaultAccentHex
            }
            BuddyAppearanceSettings.applyAppKitAppearance()
        }
    }

    private var resolvedAccentHex: String {
        BuddyAppearanceSettings.accentHex(for: brand)
    }

    private var isUsingBrandDefault: Bool {
        resolvedAccentHex.compare(brand.defaultAccentHex, options: .caseInsensitive) == .orderedSame
    }
}

private struct AccentSwatchButton: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: EditorRedactionSettings.nsColor(fromHex: hex)))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .strokeBorder(BuddyTheme.BuddyColor.textPrimary.opacity(isSelected ? 0.9 : 0.2), lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .help(hex)
        .accessibilityLabel("Theme color \(hex)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Appearance application

private struct BuddyAppearanceRootModifier: ViewModifier {
    let brand: BuddyBrand

    @AppStorage(BuddySettingsKey.appearanceColorScheme) private var colorSchemeRaw: String =
        BuddyAppearanceSettings.ColorSchemePreference.system.rawValue
    @AppStorage(BuddySettingsKey.appearanceAccentHex) private var accentHexRaw: String = ""

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(preferredScheme)
            .tint(accentColor)
            .onAppear {
                BuddyAppearanceSettings.applyAppKitAppearance()
            }
            .onChange(of: colorSchemeRaw) { _ in
                BuddyAppearanceSettings.applyAppKitAppearance()
            }
    }

    private var preferredScheme: ColorScheme? {
        switch BuddyAppearanceSettings.ColorSchemePreference(rawValue: colorSchemeRaw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var accentColor: Color {
        Color(nsColor: BuddyAppearanceSettings.accentNSColor(for: brand))
    }
}

public extension View {
    /// Applies stored light/dark preference and brand/user accent tint.
    func buddyAppearance(brand: BuddyBrand) -> some View {
        modifier(BuddyAppearanceRootModifier(brand: brand))
    }
}

// MARK: - Legal

/// Privacy Policy + Terms of Use links for App Store legal pages.
public struct BuddyLegalLinksSection: View {
    private let app: BuddyLegalURLs.App

    public init(app: BuddyLegalURLs.App) {
        self.app = app
    }

    public init(brand: BuddyBrand) {
        self.app = brand.legalApp
    }

    public var body: some View {
        Section("Legal") {
            Link("Privacy Policy", destination: BuddyLegalURLs.privacyPolicy(for: app))
                .accessibilityIdentifier("settings-privacy-policy")
            Link("Terms of Use", destination: BuddyLegalURLs.termsOfUse(for: app))
                .accessibilityIdentifier("settings-terms-of-use")
        }
    }
}
