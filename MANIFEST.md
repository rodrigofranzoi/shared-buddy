# *-buddy Manifest

Generic product contract for every Buddy macOS utility. Copy this file into each app repo and fill product-specific fields.

## Identity

| Field | Value |
|-------|-------|
| Suite | *-buddy |
| Platform | macOS only (Swift + SwiftUI) |
| Min OS | macOS 13.0 (Ventura) |
| Distribution | Mac App Store |
| Shared code | [shared-buddy](https://github.com/rodrigofranzoi/shared-buddy) Swift Package |
| Google Play / Android / Kotlin | N/A — macOS only |

## Locales

`en`, `nl`, `pt`, `es`, `fr`, `it`, `ar` (RTL), `zh`, `ru`, `ja`

## Accessibility bar

Every app must support:

- Dark Mode
- Dynamic Type / preferred content size
- VoiceOver (labels, traits, hints)
- Increase Contrast
- Reduce Motion / Reduce Transparency
- Full keyboard navigation where interactive

See [ACCESSIBILITY.md](ACCESSIBILITY.md).

## Firebase

- Apple SDK on macOS (Analytics + Crashlytics)
- No PII: never log clipboard contents, email bodies, or OTP codes
- Configure before any Firebase-backed state initializes

## Store checklist

- [ ] App Store name, subtitle, description, keywords ([STORE.md](STORE.md))
- [ ] Privacy nutrition labels
- [ ] Screenshots: raw + banners ([SCREENSHOTS.md](SCREENSHOTS.md))
- [ ] Review notes (esp. clipboard / email access)

## CI

GitHub Actions on `macos-latest`: build + unit tests (+ UI tests when scheme exists).

## Repos

| Repo | Role |
|------|------|
| `shared-buddy` | Shared SPM library |
| `clipboard-buddy` | Clipboard history + favorites |
| `screenshot-buddy` | Screenshot gallery + editor |
| `otp-buddy` | Email OTP → clipboard |

## Product (this repo)

- **Name:** shared-buddy
- **Bundle / module:** BuddyCore, BuddyUI, BuddyFirebase, BuddyLocalization, BuddyTesting
- **Purpose:** Cross-app models, tagging, OTP parsing, UI primitives, Firebase wrapper
