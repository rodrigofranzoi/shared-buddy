import SwiftUI
import BuddyCore

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
                        Text("Paused")
                            .font(BuddyTheme.Typography.label)
                        Text(pause.statusSummary)
                            .font(BuddyTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Resume") {
                        pause.resume()
                    }
                    .accessibilityIdentifier("pause-resume")
                }
                .padding(.horizontal)
                .padding(.bottom, BuddyTheme.Spacing.sm)
            } else if showCustom {
                customDurationForm
            } else {
                Menu {
                    Button("Until next session") {
                        pause.pauseUntilNextSession()
                    }
                    .accessibilityIdentifier("pause-next-session")

                    Divider()

                    ForEach(BuddyPausePreset.allCases) { preset in
                        Button(preset.title) {
                            pause.pause(preset: preset)
                        }
                    }

                    Divider()

                    Button("Custom…") {
                        showCustom = true
                    }
                    .accessibilityIdentifier("pause-custom")
                } label: {
                    Label("Turn Off", systemImage: "pause.circle")
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
            Text("Custom duration")
                .font(BuddyTheme.Typography.label)
            Stepper("Hours: \(customHours)", value: $customHours, in: 0...48)
            Stepper("Minutes: \(customMinutes)", value: $customMinutes, in: 0...59)
            HStack {
                Button("Cancel") {
                    showCustom = false
                }
                Spacer(minLength: 0)
                Button("Turn Off") {
                    let total = TimeInterval(customHours * 3600 + customMinutes * 60)
                    guard total > 0 else { return }
                    pause.pause(for: total)
                    showCustom = false
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

/// Settings toggle that drives `SMAppService` launch-at-login.
public struct BuddyLaunchAtLoginToggle: View {
    @AppStorage(BuddySettingsKey.launchAtLogin) private var launchAtLogin = true
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: BuddyTheme.Spacing.xs) {
            Toggle("Launch at login", isOn: $launchAtLogin)
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
