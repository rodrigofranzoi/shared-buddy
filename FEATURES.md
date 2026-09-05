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
| Pause / turn-off controller (session + timed + custom) | done | `BuddyPauseController` |
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
| Searchable list chrome | done | |
| Menu-bar row helpers | done | |
| Pause controls + launch-at-login toggle | done | Menu footer + Settings |
| Content blocked toolbar alert | done | Auto-dismiss + never show again |
| Dynamic Type / contrast helpers | done | Semantic system colors |
| DESIGN_SYSTEM.md contract | done | Manifest-required |

## BuddyFirebase

| Feature | Status | Notes |
|---------|--------|-------|
| Configure wrapper | done | Real FirebaseCore on macOS |
| Analytics (opt-in) | done | Spark free tier; gated by settings |
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
