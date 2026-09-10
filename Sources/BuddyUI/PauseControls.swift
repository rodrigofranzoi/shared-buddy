import SwiftUI
import AppKit
import BuddyCore
import BuddyLocalization

/// Footer for menu-bar popovers: turn off until… / resume.
public struct BuddyPauseControls: View {
    @ObservedObject private var pause: BuddyPauseController
    @State private var showCustom = false
    @State private var customHours = 0
    @State private var customMinutes = 45

    @MainActor
    public init(pause: BuddyPauseController = .shared) {
        self.pause = pause
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BuddyTheme.Spacing.sm) {
            Divider()

            if pause.isPaused {
                HStack {
                    VStack(alignment: .leading, spacing: BuddyTheme.Spacing.xxs) {
                        Text("Paused", bundle: BuddyL10n.bundle)
                            .font(BuddyTheme.Typography.label)
                        Text(pause.statusSummary)
                            .font(BuddyTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        pause.resume()
                    } label: {
                        Text("Resume", bundle: BuddyL10n.bundle)
                    }
                    .accessibilityIdentifier("pause-resume")
                }
                .padding(.horizontal)
                .padding(.bottom, BuddyTheme.Spacing.sm)
            } else if showCustom {
                customDurationForm
            } else {
                Menu {
                    Button {
                        pause.pauseUntilNextSession()
                    } label: {
                        Text("Until next session", bundle: BuddyL10n.bundle)
                    }
                    .accessibilityIdentifier("pause-next-session")

                    Button {
                        pause.pausePermanently()
                    } label: {
                        Text("Permanently", bundle: BuddyL10n.bundle)
                    }
                    .accessibilityIdentifier("pause-permanently")

                    Divider()

                    ForEach(BuddyPausePreset.allCases) { preset in
                        Button(preset.title) {
                            pause.pause(preset: preset)
                        }
                    }

                    Divider()

                    Button {
                        showCustom = true
                    } label: {
                        Text("Custom…", bundle: BuddyL10n.bundle)
                    }
                    .accessibilityIdentifier("pause-custom")
                } label: {
                    Label {
                        Text("Turn Off", bundle: BuddyL10n.bundle)
                    } icon: {
                        Image(systemName: "pause.circle")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal)
                .padding(.bottom, BuddyTheme.Spacing.sm)
                .accessibilityIdentifier("pause-menu")
            }
        }
    }

    private var customDurationForm: some View {
        VStack(alignment: .leading, spacing: BuddyTheme.Spacing.sm) {
            Text("Custom duration", bundle: BuddyL10n.bundle)
                .font(BuddyTheme.Typography.label)
            Stepper(value: $customHours, in: 0...48) {
                Text("Hours: \(customHours)", bundle: BuddyL10n.bundle)
            }
            Stepper(value: $customMinutes, in: 0...59) {
                Text("Minutes: \(customMinutes)", bundle: BuddyL10n.bundle)
            }
            HStack {
                Button {
                    showCustom = false
                } label: {
                    Text("Cancel", bundle: BuddyL10n.bundle)
                }
                Spacer(minLength: 0)
                Button {
                    let total = TimeInterval(customHours * 3600 + customMinutes * 60)
                    guard total > 0 else { return }
                    pause.pause(for: total)
                    showCustom = false
                } label: {
                    Text("Turn Off", bundle: BuddyL10n.bundle)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(customHours == 0 && customMinutes == 0)
                .accessibilityIdentifier("pause-custom-confirm")
            }
        }
        .padding(.horizontal)
        .padding(.bottom, BuddyTheme.Spacing.sm)
    }
}

/// Preferences pane for pause / resume (On, timed, session, permanent).
public struct BuddyPauseSettingsSection: View {
    @ObservedObject private var pause: BuddyPauseController
    @State private var customHours = 0
    @State private var customMinutes = 45

    @MainActor
    public init(pause: BuddyPauseController = .shared) {
        self.pause = pause
    }

    public var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: BuddyTheme.Spacing.xxs) {
                    Text(pause.isPaused ? BuddyL10n.string("Paused") : BuddyL10n.string("Active"))
                        .font(BuddyTheme.Typography.label)
                    Text(pause.statusSummary)
                        .font(BuddyTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if pause.isPaused {
                    Button {
                        pause.resume()
                    } label: {
                        Text("Resume", bundle: BuddyL10n.bundle)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("settings-pause-resume")
                }
            }

            if !pause.isPaused {
                VStack(alignment: .leading, spacing: BuddyTheme.Spacing.sm) {
                    HStack(spacing: BuddyTheme.Spacing.sm) {
                        equalWidthButton("Pause until next session", id: "settings-pause-next-session") {
                            pause.pauseUntilNextSession()
                        }
                        equalWidthButton("Pause permanently", id: "settings-pause-permanently") {
                            pause.pausePermanently()
                        }
                    }

                    HStack(spacing: BuddyTheme.Spacing.lg) {
                        Stepper(value: $customHours, in: 0...48) {
                            Text("Hours: \(customHours)", bundle: BuddyL10n.bundle)
                        }
                        Stepper(value: $customMinutes, in: 0...59) {
                            Text("Minutes: \(customMinutes)", bundle: BuddyL10n.bundle)
                        }
                    }

                    HStack(spacing: BuddyTheme.Spacing.sm) {
                        equalWidthMenu("Pause for…", id: "settings-pause-preset-menu") {
                            ForEach(BuddyPausePreset.allCases) { preset in
                                Button(preset.title) {
                                    pause.pause(preset: preset)
                                }
                            }
                        }
                        equalWidthButton(
                            "Pause for custom duration",
                            id: "settings-pause-custom",
                            disabled: customHours == 0 && customMinutes == 0
                        ) {
                            let total = TimeInterval(customHours * 3600 + customMinutes * 60)
                            guard total > 0 else { return }
                            pause.pause(for: total)
                        }
                    }
                }
            }
        } header: {
            Text("Monitoring", bundle: BuddyL10n.bundle)
        } footer: {
            Text(
                "While paused, new clipboard or screenshot captures are not saved. Permanent pause survives relaunch until you resume.",
                bundle: BuddyL10n.bundle
            )
            .font(BuddyTheme.Typography.caption)
        }
    }

    private func equalWidthButton(
        _ title: String,
        id: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title), bundle: BuddyL10n.bundle)
                .frame(maxWidth: .infinity, minHeight: 22)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(disabled)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(id)
    }

    private func equalWidthMenu<Content: View>(
        _ title: String,
        id: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            Text(LocalizedStringKey(title), bundle: BuddyL10n.bundle)
                .frame(maxWidth: .infinity, minHeight: 22)
                .multilineTextAlignment(.center)
        }
        .menuStyle(.borderedButton)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(id)
    }
}

/// Settings toggle that drives `SMAppService` launch-at-login.
public struct BuddyLaunchAtLoginToggle: View {
    @AppStorage(BuddySettingsKey.launchAtLogin) private var launchAtLogin = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: BuddyTheme.Spacing.xs) {
            Toggle(isOn: $launchAtLogin) {
                Text("Launch at login", bundle: BuddyL10n.bundle)
            }
            .onChange(of: launchAtLogin) { enabled in
                do {
                    try BuddyLaunchAtLogin.setEnabled(enabled)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                    launchAtLogin = BuddyLaunchAtLogin.isEnabled
                }
            }
            .onAppear {
                BuddyLaunchAtLogin.refreshFromSystem()
                launchAtLogin = BuddyLaunchAtLogin.isEnabled
            }
            .accessibilityIdentifier("launch-at-login-toggle")

            if let errorMessage {
                Text(errorMessage)
                    .font(BuddyTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
