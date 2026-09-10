#!/usr/bin/env python3
"""Convert STORE.md + docs/screenshots/*/banners into Fastlane deliver layout.

Usage (from an app repo root):
  python3 Vendor/shared-buddy/scripts/store/prepare_deliver_metadata.py
  python3 Vendor/shared-buddy/scripts/store/prepare_deliver_metadata.py --app screenshot
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

# Short STORE / screenshot codes → App Store Connect locale folders
LOCALE_MAP: dict[str, str] = {
    "en": "en-US",
    "de": "de-DE",
    "nl": "nl-NL",
    "pt": "pt-PT",
    "es": "es-ES",
    "fr": "fr-FR",
    "it": "it",
    "ar": "ar-SA",
    "zh": "zh-Hans",
    "ru": "ru",
    "ja": "ja",
}

# Preferred App Store screenshot order (feature IDs under docs/screenshots/*/banners/)
SCREENSHOT_ORDER: dict[str, list[str]] = {
    "screenshot": ["gallery", "editor", "redact", "smart", "qr", "menubar"],
    "paint": ["palette", "menubar", "favorites", "history", "detail", "pick"],
    "clipboard": ["history", "tags", "favorites", "qr", "detail", "menubar"],
    "otp": ["connect", "alert", "autocopy"],
}

APP_ALIASES: dict[str, str] = {
    "screenshot": "screenshot",
    "capture": "screenshot",
    "screenshot-buddy": "screenshot",
    "paint": "paint",
    "paint-buddy": "paint",
    "clipboard": "clipboard",
    "clipboard-buddy": "clipboard",
    "otp": "otp",
    "otp-buddy": "otp",
}

LOCALE_HEADING = re.compile(
    r"^##\s+.+\(`([a-z]{2})`\)\s*$",
    re.MULTILINE,
)
FIELD = re.compile(
    r"^\*\*(Name|Subtitle|Keywords|Promotional Text):\*\*\s*(.+?)\s*$",
    re.MULTILINE,
)


def detect_app(root: Path, explicit: str | None) -> str:
    if explicit:
        key = APP_ALIASES.get(explicit.lower())
        if not key:
            raise SystemExit(f"Unknown --app {explicit!r}. Expected one of: {sorted(set(APP_ALIASES))}")
        return key

    name = root.name.lower()
    for alias, key in APP_ALIASES.items():
        if name == alias or name.startswith(alias):
            return key

    store = (root / "STORE.md").read_text(encoding="utf-8")[:200].lower()
    for key in ("screenshot", "paint", "clipboard", "otp"):
        if key in store or (key == "screenshot" and "capture buddy" in store):
            return key
    raise SystemExit("Could not detect app; pass --app screenshot|paint|clipboard|otp")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = content.strip() + "\n"
    path.write_text(text, encoding="utf-8")


def extract_fenced_block_after(heading: str, store: str) -> str:
    """Return the first ``` ... ``` block after a markdown heading substring."""
    idx = store.find(heading)
    if idx < 0:
        return ""
    rest = store[idx:]
    m = re.search(r"```(?:\w*)\n(.*?)```", rest, re.DOTALL)
    return (m.group(1) if m else "").strip()


def parse_global(store: str) -> dict[str, str]:
    privacy = ""
    terms = ""
    app_store_id = ""
    copyright_year = "2026"

    m = re.search(r"App Store ID:\s*`?(\d+)`?", store)
    if m:
        app_store_id = m.group(1)
    m = re.search(r"Privacy:\s*(\S+)", store)
    if m:
        privacy = m.group(1).strip()
    m = re.search(r"Terms:\s*(\S+)", store)
    if m:
        terms = m.group(1).strip()

    whats_new = ""
    m = re.search(
        r"## What's New \(all locales\)\s*\n+(.+?)(?:\n---|\n## )",
        store,
        re.DOTALL,
    )
    if m:
        whats_new = m.group(1).strip()

    review_notes = extract_fenced_block_after("## App Review Notes", store)

    return {
        "privacy_url": privacy,
        "marketing_url": terms,
        "support_url": terms or privacy,
        "app_store_id": app_store_id,
        "release_notes": whats_new or "Initial release.",
        "review_notes": review_notes,
        "copyright": f"{copyright_year} Rodrigo Scroferneker",
    }


def parse_locales(store: str) -> dict[str, dict[str, str]]:
    matches = list(LOCALE_HEADING.finditer(store))
    locales: dict[str, dict[str, str]] = {}
    for i, m in enumerate(matches):
        code = m.group(1)
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(store)
        block = store[start:end]
        # Stop at Google Play / trailing sections without locale code
        for stopper in ("\n## Google Play", "\n## Feature highlights"):
            cut = block.find(stopper)
            if cut >= 0:
                block = block[:cut]

        fields: dict[str, str] = {}
        for fm in FIELD.finditer(block):
            key = {
                "Name": "name",
                "Subtitle": "subtitle",
                "Keywords": "keywords",
                "Promotional Text": "promotional_text",
            }[fm.group(1)]
            fields[key] = fm.group(2).strip()

        desc = ""
        dm = re.search(r"\*\*Description:\*\*\s*\n+(.*)", block, re.DOTALL)
        if dm:
            desc = dm.group(1).strip()
            # Trim trailing --- / next heading leftovers
            desc = re.split(r"\n---\s*\n", desc)[0].strip()
        fields["description"] = desc
        locales[code] = fields
    return locales


def sync_screenshots(root: Path, app: str, out_screenshots: Path) -> int:
    order = SCREENSHOT_ORDER.get(app, [])
    src_root = root / "docs" / "screenshots"
    if out_screenshots.exists():
        shutil.rmtree(out_screenshots)
    out_screenshots.mkdir(parents=True, exist_ok=True)

    count = 0
    if not src_root.is_dir():
        print(f"warn: no screenshots dir at {src_root}", file=sys.stderr)
        return 0

    for short in sorted(p.name for p in src_root.iterdir() if p.is_dir()):
        if short not in LOCALE_MAP:
            continue
        banners = src_root / short / "banners"
        if not banners.is_dir():
            continue
        asc = LOCALE_MAP[short]
        dest = out_screenshots / asc
        dest.mkdir(parents=True, exist_ok=True)

        # Prefer known App Store order only (do not append extra banner PNGs like dropped shots).
        ordered: list[Path] = []
        if order:
            for feature_id in order:
                path = banners / f"{feature_id}.png"
                if path.is_file():
                    ordered.append(path)
        else:
            ordered = sorted(banners.glob("*.png"))

        for idx, path in enumerate(ordered, start=1):
            target = dest / f"{idx:02d}_{path.stem}.png"
            shutil.copy2(path, target)
            count += 1
    return count


def prepare(root: Path, app: str, skip_screenshots: bool) -> None:
    store_path = root / "STORE.md"
    if not store_path.is_file():
        raise SystemExit(f"Missing {store_path}")

    store = store_path.read_text(encoding="utf-8")
    global_meta = parse_global(store)
    locales = parse_locales(store)
    if not locales:
        raise SystemExit("No locale sections found in STORE.md (expected ## English (`en`), …)")

    meta_root = root / "fastlane" / "metadata"
    if meta_root.exists():
        shutil.rmtree(meta_root)
    meta_root.mkdir(parents=True, exist_ok=True)

    write_text(meta_root / "copyright.txt", global_meta["copyright"])
    write_text(meta_root / "primary_category.txt", "PRODUCTIVITY")
    write_text(meta_root / "secondary_category.txt", "UTILITIES")

    if global_meta["review_notes"]:
        write_text(meta_root / "review_information" / "notes.txt", global_meta["review_notes"])

    for short, fields in locales.items():
        asc = LOCALE_MAP.get(short)
        if not asc:
            print(f"warn: skip unknown locale {short!r}", file=sys.stderr)
            continue
        loc_dir = meta_root / asc
        mapping = {
            "name": "name.txt",
            "subtitle": "subtitle.txt",
            "keywords": "keywords.txt",
            "promotional_text": "promotional_text.txt",
            "description": "description.txt",
        }
        for key, filename in mapping.items():
            value = fields.get(key, "").strip()
            if value:
                write_text(loc_dir / filename, value)
        write_text(loc_dir / "release_notes.txt", global_meta["release_notes"])
        if global_meta["privacy_url"]:
            write_text(loc_dir / "privacy_url.txt", global_meta["privacy_url"])
        if global_meta["support_url"]:
            write_text(loc_dir / "support_url.txt", global_meta["support_url"])
        if global_meta["marketing_url"]:
            write_text(loc_dir / "marketing_url.txt", global_meta["marketing_url"])

    shot_count = 0
    if not skip_screenshots:
        shot_count = sync_screenshots(root, app, root / "fastlane" / "screenshots")

    print(
        f"Prepared deliver metadata for {app}: "
        f"{len(locales)} locales → {meta_root.relative_to(root)}; "
        f"{shot_count} screenshots"
        + ("" if global_meta["app_store_id"] else " (no App Store ID in STORE.md)")
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", help="screenshot|paint|clipboard|otp (auto-detected from cwd)")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="App repo root")
    parser.add_argument("--skip-screenshots", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    app = detect_app(root, args.app)
    prepare(root, app, args.skip_screenshots)


if __name__ == "__main__":
    main()
