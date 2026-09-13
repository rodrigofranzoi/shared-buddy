#!/usr/bin/env bash
# Build Buddy apps and capture real App Store screenshots per locale.
set -euo pipefail
setopt NULL_GLOB 2>/dev/null || true

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LANGS=(en de nl pt es fr it ar zh ru ja)
DERIVED="${TMPDIR:-/tmp}/buddy-marketing-derived"
CONFIGURATION="${CONFIGURATION:-Debug}"

build_app() {
  local dir="$1"
  local scheme="$2"
  local source_name="$3"
  local product_name="${4:-$source_name}"
  echo "==> Building $product_name (scheme $scheme)" >&2
  local marketing_ents="${dir}/${source_name}/${source_name}-Marketing.entitlements"
  local ents_args=()
  if [[ -f "$marketing_ents" ]]; then
    ents_args=(CODE_SIGN_ENTITLEMENTS="$marketing_ents")
    echo "    (using marketing entitlements without App Sandbox for capture writes)" >&2
  fi
  (
    cd "$dir"
    xcodegen generate >/dev/null
    if ((${#ents_args[@]})); then
      xcodebuild \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED/$scheme" \
        -destination 'platform=macOS' \
        "${ents_args[@]}" \
        build
    else
      xcodebuild \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED/$scheme" \
        -destination 'platform=macOS' \
        build
    fi
  ) >/tmp/buddy-build-"$scheme".log 2>&1 || {
    echo "ERROR: build failed for $product_name — see /tmp/buddy-build-$scheme.log" >&2
    tail -40 "/tmp/buddy-build-$scheme.log" >&2 || true
    exit 1
  }
  local app
  app="$(find "$DERIVED/$scheme/Build/Products/$CONFIGURATION" -maxdepth 2 -name "${product_name}.app" | head -1)"
  if [[ -z "$app" ]]; then
    echo "ERROR: could not find ${product_name}.app — see /tmp/buddy-build-$scheme.log" >&2
    exit 1
  fi
  # Reject stale apps from a previous successful build if this build failed earlier.
  touch "$app"  # Ensure Firebase plist is present for configure().
  local plist_src="$dir/$source_name/Resources/GoogleService-Info.plist"
  if [[ -f "$plist_src" ]]; then
    cp "$plist_src" "$app/Contents/Resources/GoogleService-Info.plist"
  fi
  echo "$app"
}

capture_locale() {
  local app="$1"
  local out_raw="$2"
  local lang="$3"
  mkdir -p "$out_raw"
  find "$out_raw" -maxdepth 1 -name '*.png' -delete

  local bin="$app/Contents/MacOS/$(basename "$app" .app)"
  killall "$(basename "$app" .app)" 2>/dev/null || true
  sleep 0.3

  echo "  capturing $(basename "$app" .app) [$lang]" >&2
  "$bin" \
    -BuddyMarketingCapture \
    -BuddyCaptureOut "$out_raw" \
    -AppleLanguages "($lang)" \
    >/tmp/buddy-capture-"$(basename "$app" .app)"-"$lang".log 2>&1 || true

  local count
  count="$(find "$out_raw" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
  if [[ "$count" -lt 1 ]]; then
    echo "ERROR: no PNGs for $lang — see /tmp/buddy-capture-$(basename "$app" .app)-$lang.log" >&2
    cat "/tmp/buddy-capture-$(basename "$app" .app)-$lang.log" >&2 || true
    exit 1
  fi
}

frame_banners() {
  python3 "$ROOT/shared-buddy/scripts/marketing/generate_marketing_banners.py" --frame-only "$@"
}

main() {
  local only="${1:-all}"
  local shot_app=""
  local clip_app=""
  local paint_app=""
  local otp_app=""

  if [[ "$only" == "all" || "$only" == "screenshot" ]]; then
    shot_app="$(build_app "$ROOT/screenshot-buddy" ScreenshotBuddy ScreenshotBuddy "Capture Buddy")"
  fi
  if [[ "$only" == "all" || "$only" == "clipboard" ]]; then
    clip_app="$(build_app "$ROOT/clipboard-buddy" ClipboardBuddy ClipboardBuddy "ClipLog Buddy")"
  fi
  if [[ "$only" == "all" || "$only" == "paint" ]]; then
    paint_app="$(build_app "$ROOT/paint-buddy" PaintBuddy PaintBuddy)"
  fi
  if [[ "$only" == "all" || "$only" == "otp" ]]; then
    otp_app="$(build_app "$ROOT/otp-buddy" OTPBuddy OTPBuddy "OTP Buddy")"
  fi

  for lang in "${LANGS[@]}"; do
    if [[ -n "$shot_app" ]]; then
      capture_locale "$shot_app" \
        "$ROOT/screenshot-buddy/docs/screenshots/$lang/raw" \
        "$lang"
    fi
    if [[ -n "$clip_app" ]]; then
      capture_locale "$clip_app" \
        "$ROOT/clipboard-buddy/docs/screenshots/$lang/raw" \
        "$lang"
    fi
    if [[ -n "$paint_app" ]]; then
      capture_locale "$paint_app" \
        "$ROOT/paint-buddy/docs/screenshots/$lang/raw" \
        "$lang"
    fi
    if [[ -n "$otp_app" ]]; then
      capture_locale "$otp_app" \
        "$ROOT/otp-buddy/docs/screenshots/$lang/raw" \
        "$lang"
    fi
  done

  echo "==> Framing banners from real captures" >&2
  if [[ "$only" == "paint" ]]; then
    frame_banners --app paint
  elif [[ "$only" == "screenshot" ]]; then
    frame_banners --app screenshot
  elif [[ "$only" == "clipboard" ]]; then
    frame_banners --app clipboard
  elif [[ "$only" == "otp" ]]; then
    frame_banners --app otp
  else
    frame_banners
  fi
  echo "Done." >&2
}

main "${1:-all}"
