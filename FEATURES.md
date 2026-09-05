# shared-buddy Features

Status: `planned` | `wip` | `done`

## BuddyCore

| Feature | Status | Notes |
|---------|--------|-------|
| Content tag classifiers (URL, email, phone, password, token, SHA, IBAN, card, OTP, JSON, path, color, image) | done | Extensible `ContentTagger` |
| OTP extraction from email/text | done | Conservative scoring |
| Keychain helper | done | Generic credential store |
| Settings key constants | done | Shared UserDefaults keys |
| Favorite shortcut model | done | Name + payload |
| Clipboard item model | done | Text/image + tags |
| Screenshot item model | done | Image + redactions |

## BuddyUI

| Feature | Status | Notes |
|---------|--------|-------|
| Tag chip view | done | Accessibility labeled |
| Blur / redact overlay primitives | done | For sensitive content |
| Searchable list chrome | done | |
| Menu-bar row helpers | done | |
| Dynamic Type / contrast helpers | done | |

## BuddyFirebase

| Feature | Status | Notes |
|---------|--------|-------|
| Configure wrapper | done | No-op when plist missing (dev) |
| Analytics event names (no PII) | done | |
| Crashlytics breadcrumb helpers | done | |

## BuddyLocalization

| Feature | Status | Notes |
|---------|--------|-------|
| Locale list + RTL helper | done | |
| Shared string catalog stub | done | Apps own most strings |

## BuddyTesting

| Feature | Status | Notes |
|---------|--------|-------|
| Sample fixtures (OTP emails, clipboard samples) | done | |
