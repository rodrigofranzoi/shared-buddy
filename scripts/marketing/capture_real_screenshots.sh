#!/usr/bin/env bash
# Build Screenshot/Clipboard Buddy and capture real App Store screenshots per locale.
set -euo pipefail
setopt NULL_GLOB 2>/dev/null || true

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LANGS=(en nl pt es fr it ar zh ru ja)
DERIVED="${TMPDIR:-/tmp}/buddy-marketing-derived"
CONFIGURATION="${CONFIGURATION:-Debug}"

build_app() {
  local dir="$1"
  local scheme="$2"
  local name="$3"
  echo "==> Building $name" >&2
  (
    cd "$dir"
    xcodegen generate >/dev/null
    xcodebuild \
      -scheme "$scheme" \
      -configuration "$CONFIGURATION" \
      -derivedDataPath "$DERIVED/$scheme" \
      -destination 'platform=macOS' \
      build
  ) >/tmp/buddy-build-"$scheme".log 2>&1 || {
    echo "ERROR: build failed for $name — see /tmp/buddy-build-$scheme.log" >&2
    tail -40 "/tmp/buddy-build-$scheme.log" >&2 || true
    exit 1
  }
  local app
  app="$(find "$DERIVED/$scheme/Build/Products/$CONFIGURATION" -maxdepth 2 -name "$name.app" | head -1)"
  if [[ -z "$app" ]]; then
    echo "ERROR: could not find $name.app — see /tmp/buddy-build-$scheme.log" >&2
    exit 1
  fi
  # Reject stale apps from a previous successful build if this build failed earlier.
  touch "$app"  # Ensure Firebase plist is present for configure().
  local plist_src="$dir/$name/Resources/GoogleService-Info.plist"
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
  python3 "$ROOT/shared-buddy/scripts/marketing/generate_marketing_banners.py" --frame-only
}

main() {
  local only="${1:-all}"
  local shot_app=""
  local clip_app=""

  if [[ "$only" == "all" || "$only" == "screenshot" ]]; then
    shot_app="$(build_app "$ROOT/screenshot-buddy" ScreenshotBuddy ScreenshotBuddy)"
  fi
  if [[ "$only" == "all" || "$only" == "clipboard" ]]; then
    clip_app="$(build_app "$ROOT/clipboard-buddy" ClipboardBuddy ClipboardBuddy)"
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
  done

  echo "==> Framing banners from real captures" >&2
  frame_banners
  echo "Done." >&2
}

main "${1:-all}"
