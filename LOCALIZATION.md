# Localization — *-buddy

## Supported locales

| Code | Language |
|------|----------|
| en | English (source) |
| de | German |
| nl | Dutch |
| pt | Portuguese |
| es | Spanish |
| fr | French |
| it | Italian |
| ar | Arabic (RTL) |
| zh | Chinese (Simplified) |
| ru | Russian |
| ja | Japanese |

> Note: product brief used `zn` / `jp`; ISO codes are `zh` / `ja`.

## Architecture

- **App catalogs** (`*/Resources/Localizable.xcstrings`): strings owned by each app’s views and `String(localized:)` calls. SwiftUI `Text("…")` resolves against the app main bundle.
- **Shared catalog** (`shared-buddy/.../BuddyLocalization/Resources/Localizable.xcstrings`): settings, pause, history, privacy, tags, and other BuddyUI/BuddyCore copy. Looked up via `BuddyL10n.bundle` (`Bundle.module`).
- Prefer `Text("Key", bundle: BuddyL10n.bundle)` / `BuddyL10n.string("Key")` in shared code. Use `BuddyText(verbatim:)` for dynamic (non-localized) content such as clipboard payloads.

## Workflow

1. Add English keys to the correct String Catalog (app vs shared)
2. Translate all 11 locales
3. Verify RTL layout with `ar`
4. Update [STORE.md](STORE.md) per locale for App Store Connect
