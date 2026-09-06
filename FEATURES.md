# shared-buddy Features

Status: `planned` | `wip` | `done`

## BuddyCore

| Feature | Status | Notes |
|---------|--------|-------|
| Content tag classifiers (URL, email, phone, password, token, SHA, IBAN, card, OTP, JSON, path, color, image) | done | Extensible `ContentTagger` |
| Adult / sexual content block (`ContentSafety`) | done | Text + OCR; violence/profanity allowed |
| OTP extraction from email/text | done | Conservative scoring |
| Keychain helper | done | Generic credential store |
| Settings key constants | done | Shared UserDefaults keys |
| Appearance (scheme + accent hex) | done | `BuddyAppearanceSettings`, `BuddyBrand` defaults |
| Sensitive privacy settings + 10‑min unlock session | done | `SensitivePrivacySettings`, `SensitiveUnlockSession` |
| Sensitive region OCR for screenshot redaction | done | `SensitiveRegionFinder` |
| Pause / turn-off controller (session + timed + custom) | done | `BuddyPauseController` |
| Permanent pause (survives relaunch) | done | `BuddySettingsKey.pausePermanently` |
| Clipboard ignore-apps list | done | `ClipboardIgnoreSettings` |
| History limit keys (clipboard + screenshot) | done | Max count + menu-bar counts |
| Launch at login (SMAppService, default on first install) | done | `BuddyLaunchAtLogin` |
| Favorite shortcut model | done | Name + payload |
| Clipboard item model | done | Text/image + tags |
| Screenshot item model | done | Image + redactions |

## BuddyUI

| Feature | Status | Notes |
|---------|--------|-------|
| Design tokens (`BuddyTheme`) | done | Color, type, spacing, radius, motion |
| Atomic components | done | Text, icon, button, badge, divider |
| Tag chip view | done | Accessibility labeled |
| Blur / redact overlay primitives | done | For sensitive content |
| Sensitive privacy settings section | done | Blur + Touch ID toggles shared by apps |
| Sidebar settings chrome + appearance pane | done | `BuddySettingsSidebarView`, theme color + light/dark |
| Searchable list chrome | done | |
| Menu-bar row helpers | done | |
| Pause controls + launch-at-login toggle | done | Menu footer + Settings |
| Pause settings section + permanent option | done | `BuddyPauseSettingsSection` |
| Clippings / screenshot history settings | done | `ClipboardClippingsSettingsSection`, `ScreenshotHistorySettingsSection` |
| Ignored apps settings | done | `ClipboardIgnoredAppsSettingsSection` |
| Erase all history (settings + menu/toolbar) | done | `BuddyClearHistorySettingsSection`, `BuddyClearHistoryButton` |
| Open main window + Quit from menu bar | done | `BuddyMainWindow`, `BuddyMenuBarAppControls` |
| Content blocked toolbar alert | done | Auto-dismiss + never show again |
| Dynamic Type / contrast helpers | done | Semantic system colors |
| DESIGN_SYSTEM.md contract | done | Manifest-required |

## BuddyFirebase

| Feature | Status | Notes |
|---------|--------|-------|
| Configure wrapper | done | Real FirebaseCore on macOS |
| Analytics | done | Spark free tier; always enabled; no PII |
| Crashlytics | done | NSApplicationCrashOnExceptions |
| Analytics event names (no PII) | done | |
| Crashlytics breadcrumb helpers | done | |
| Project buddy-suite-macos | done | 3 Apple apps registered |

## BuddyLocalization

| Feature | Status | Notes |
|---------|--------|-------|
| Locale list + RTL helper | done | |
| Shared string catalog stub | done | Apps own most strings |

## BuddyTesting

| Feature | Status | Notes |
|---------|--------|-------|
| Sample fixtures (OTP emails, clipboard samples) | done | |
