# Firebase — Buddy Suite (Spark / free tier)

**Project ID:** `buddy-suite-macos`  
**Plan:** Spark (free) — Analytics + Crashlytics only  
**Console:** https://console.firebase.google.com/project/buddy-suite-macos

## Apps (Apple / macOS)

Registered via Firebase CLI as iOS-platform Apple apps (standard for macOS menu-bar utilities):

| App | Bundle ID | App ID |
|-----|-----------|--------|
| Clipboard Buddy | `com.buddy.clipboard` | `1:304015834291:ios:19b1eb4b7dfa2a3f3844c6` |
| Screenshot Buddy | `com.buddy.screenshot` | `1:304015834291:ios:6a8f7c0223aba8b13844c6` |
| OTP Buddy | `com.buddy.otp` | `1:304015834291:ios:3785c79c44a859a03844c6` |

Config files live at `{App}/Resources/GoogleService-Info.plist`.

## SDK

- Linked through `BuddyFirebase` in `shared-buddy` (FirebaseCore, Analytics, Crashlytics 12.18+)
- Apps call `BuddyFirebase.configure()` in `App.init()` before other Firebase-backed state
- Analytics collection is always enabled; Crashlytics is enabled after configure
- `NSApplicationCrashOnExceptions` = YES in Info.plist
- No PII: never log clipboard, screenshots, email, or OTP codes

## Local

```bash
ln -sfn ../../shared-buddy Vendor/shared-buddy
xcodegen generate
open *.xcodeproj
```

Ensure outgoing network entitlement is enabled (already in entitlements).
