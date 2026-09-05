# Testing — shared-buddy

## Unit tests

```bash
cd shared-buddy
swift test
```

Coverage focus:

- `ContentTagger` classification
- `OTPDetector` extraction
- Keychain round-trip (when entitlements allow; otherwise mock)
- Localization locale list

## UI / e2e

N/A for the package itself. Apps run XCUITest against schemes.

## CI

`.github/workflows/ci.yml` runs `swift test` on `macos-latest`.
