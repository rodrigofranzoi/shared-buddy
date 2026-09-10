# Store / Fastlane helpers

| File | Purpose |
|------|---------|
| `prepare_deliver_metadata.py` | Parse each app’s `STORE.md` + `docs/screenshots/*/banners` → `fastlane/metadata` + `fastlane/screenshots` |
| `Fastfile` | Shared macOS lanes: `prepare`, `build`, `beta`, `metadata`, `screenshots`, `release` |

Apps import the Fastfile from their own `fastlane/Fastfile` and set `BUDDY_*` env defaults. See `screenshot-buddy/FASTLANE.md`.
