#!/usr/bin/env python3
"""Add German (de) localizations to Paint Buddy + shared BuddyLocalization catalogs."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# English source (or catalog key) -> German
DE: dict[str, str] = {
    # --- Paint Buddy ---
    "Add Color": "Farbe hinzufügen",
    "Add Favorite": "Favorit hinzufügen",
    "Add favorite color": "Favoritenfarbe hinzufügen",
    "Add to Favorites": "Zu Favoriten hinzufügen",
    "Analogous +": "Analog +",
    "Analogous −": "Analog −",
    "Captured": "Erfasst",
    "Clipboard": "Zwischenablage",
    "Color": "Farbe",
    "Color Panel": "Farbpanel",
    "Colors": "Farben",
    "Complementary": "Komplementär",
    "Copied": "Kopiert",
    "Copy": "Kopieren",
    "Copy %@": "%@ kopieren",
    "Copy %1$@ %2$@": "%1$@ %2$@ kopieren",
    "%1$@ %2$@": "%1$@ %2$@",
    "Copy Preferred Format": "Bevorzugtes Format kopieren",
    "Copy a color or pick one": "Farbe kopieren oder auswählen",
    "Darker": "Dunkler",
    "Delete": "Löschen",
    "Enter a hex or rgba color": "Hex- oder RGBA-Farbe eingeben",
    "Favorite": "Favorit",
    "Favorited": "Favorisiert",
    "Favorites": "Favoriten",
    "Favorites Palette": "Favoritenpalette",
    "Floating Favorites": "Schwebende Favoriten",
    "Floating History": "Schwebende Historie",
    "Floating Palette": "Schwebende Palette",
    "Hex": "Hex",
    "History": "Historie",
    "History Palette": "Historienpalette",
    "History or Favorites": "Historie oder Favoriten",
    "Lighter": "Heller",
    "Much darker": "Viel dunkler",
    "Much lighter": "Viel heller",
    "Muted": "Gedämpft",
    "No #": "Ohne #",
    "No colors yet": "Noch keine Farben",
    "No favorites yet": "Noch keine Favoriten",
    "Open Favorites": "Favoriten öffnen",
    "Open History": "Historie öffnen",
    "Paint Buddy": "Paint Buddy",
    "Paint Buddy (paused)": "Paint Buddy (pausiert)",
    "Palette": "Palette",
    "Palette layout": "Palettenlayout",
    "Pick Color": "Farbe wählen",
    "Pick Favorite Color": "Favoritenfarbe wählen",
    "Pick a color or add one manually": "Farbe wählen oder manuell hinzufügen",
    "Pick a color, add one manually, or favorite from history": "Farbe wählen, manuell hinzufügen oder aus der Historie favorisieren",
    "RGB": "RGB",
    "RGBA": "RGBA",
    "Recent": "Zuletzt",
    "Remove Favorite": "Favorit entfernen",
    "Select a color": "Farbe auswählen",
    "Settings": "Einstellungen",
    "Source": "Quelle",
    "Startup": "Start",
    "Suggestions": "Vorschläge",
    "Unrecognized color": "Unbekannte Farbe",
    "Values": "Werte",
    "View": "Ansicht",
    "colors": "Farben",
    # --- Shared / BuddyLocalization ---
    "1 hour": "1 Stunde",
    "15 minutes": "15 Minuten",
    "2 hours": "2 Stunden",
    "20 minutes": "20 Minuten",
    "30 minutes": "30 Minuten",
    "4 hours": "4 Stunden",
    "5 minutes": "5 Minuten",
    "8 hours": "8 Stunden",
    "API keys": "API-Schlüssel",
    "Account": "Konto",
    "Active": "Aktiv",
    "Add App…": "App hinzufügen…",
    "Amounts": "Beträge",
    "Appearance": "Erscheinungsbild",
    "Ask for password or Touch ID to view sensitive content": "Passwort oder Touch ID anfordern, um sensible Inhalte anzuzeigen",
    "Auto-blur": "Auto-Unschärfe",
    "Blocked content": "Blockierte Inhalte",
    "Reveal": "Anzeigen",
    "Search": "Suchen",
    "Cancel": "Abbrechen",
    "Cards": "Karten",
    "Choose apps whose clipboard copies should be ignored": "Apps wählen, deren Zwischenablage-Kopien ignoriert werden sollen",
    "Clipboard Capture": "Zwischenablage-Erfassung",
    "Clippings": "Ausschnitte",
    "Content blocked": "Inhalt blockiert",
    "Copies made while these apps are frontmost are not saved to Clipboard Buddy history.": "Kopien, während diese Apps im Vordergrund sind, werden nicht in der Clipboard-Buddy-Historie gespeichert.",
    "Copy as": "Kopieren als",
    "Copy to clipboard": "In die Zwischenablage kopieren",
    "Custom color": "Benutzerdefinierte Farbe",
    "Custom duration": "Benutzerdefinierte Dauer",
    "Custom…": "Benutzerdefiniert…",
    "Dark": "Dunkel",
    "Default for %@ is %@.": "Standard für %@ ist %@.",
    "Detected color": "Erkannte Farbe",
    "Detected link": "Erkannter Link",
    "Disable password or Touch ID protection": "Passwort- oder Touch-ID-Schutz deaktivieren",
    "Dismiss": "Schließen",
    "Double tap to reveal": "Doppeltippen zum Anzeigen",
    "Emails": "E-Mails",
    "Erase All": "Alles löschen",
    "Erase All History…": "Gesamte Historie löschen…",
    "Erase all %@?": "Alle %@ löschen?",
    "Erase all history": "Gesamte Historie löschen",
    "Files": "Dateien",
    "Floating swatch size: %lld pt": "Schwebende Swatch-Größe: %lld pt",
    "Hashes": "Hashes",
    "Hex (#RRGGBB)": "Hex (#RRGGBB)",
    "Hex without # (RRGGBB)": "Hex ohne # (RRGGBB)",
    "Hidden sensitive content": "Versteckte sensible Inhalte",
    "Hours: %lld": "Stunden: %lld",
    "IBANs": "IBANs",
    "If %@ helps your workflow, a quick rating on the App Store means a lot.": "Wenn %@ Ihren Workflow unterstützt, bedeutet eine kurze Bewertung im App Store sehr viel.",
    "Ignore": "Ignorieren",
    "Ignored Apps": "Ignorierte Apps",
    "Images": "Bilder",
    "JSON": "JSON",
    "Launch at login": "Bei Anmeldung starten",
    "Legal": "Rechtliches",
    "Light": "Hell",
    "Matching items stay blurred until unlocked, then remain visible for 10 minutes.": "Passende Einträge bleiben unscharf bis zur Entsperrung und sind danach 10 Minuten sichtbar.",
    "Minutes: %lld": "Minuten: %lld",
    "Mode": "Modus",
    "Monitoring": "Überwachung",
    "Never show again": "Nicht mehr anzeigen",
    "No apps ignored": "Keine Apps ignoriert",
    "Not Now": "Nicht jetzt",
    "OTPs": "OTPs",
    "Off": "Aus",
    "Off permanently": "Dauerhaft aus",
    "Off until %@": "Aus bis %@",
    "Off until next session": "Aus bis zur nächsten Sitzung",
    "Older clippings beyond the remember limit are removed automatically. Favorites are kept separately.": "Ältere Ausschnitte über dem Speicherlimit werden automatisch entfernt. Favoriten bleiben separat erhalten.",
    "Older colors beyond the remember limit are removed automatically.": "Ältere Farben über dem Speicherlimit werden automatisch entfernt.",
    "Older screenshots beyond the remember limit are removed automatically.": "Ältere Screenshots über dem Speicherlimit werden automatisch entfernt.",
    "On": "An",
    "Only enabled formats are added to history when you copy a color.": "Nur aktivierte Formate werden beim Kopieren einer Farbe zur Historie hinzugefügt.",
    "Open": "Öffnen",
    "Open %@": "%@ öffnen",
    "Open %@ when you log in?": "%@ beim Anmelden öffnen?",
    "Open at Login": "Bei Anmeldung öffnen",
    "Open floating history on launch": "Schwebende Historie beim Start öffnen",
    "Open floating palette on launch": "Schwebende Palette beim Start öffnen",
    "Open link": "Link öffnen",
    "Other": "Sonstiges",
    "PDFs": "PDFs",
    "Passwords": "Passwörter",
    "Paths": "Pfade",
    "Pause for custom duration": "Für benutzerdefinierte Dauer pausieren",
    "Pause for…": "Pausieren für…",
    "Pause permanently": "Dauerhaft pausieren",
    "Pause until next session": "Bis zur nächsten Sitzung pausieren",
    "Paused": "Pausiert",
    "Permanently": "Dauerhaft",
    "Phones": "Telefone",
    "Preferences": "Einstellungen",
    "Preferred Format": "Bevorzugtes Format",
    "Privacy": "Datenschutz",
    "Privacy Policy": "Datenschutzerklärung",
    "Quit %@": "%@ beenden",
    "Rate %@": "%@ bewerten",
    "Rate App": "App bewerten",
    "Remember %lld clippings": "%lld Ausschnitte merken",
    "Remember %lld colors": "%lld Farben merken",
    "Remember %lld screenshots": "%lld Screenshots merken",
    "Remember screenshots": "Screenshots merken",
    "Removes all saved %@ from this Mac. This cannot be undone.": "Löscht alle gespeicherten %@ von diesem Mac. Das kann nicht rückgängig gemacht werden.",
    "Reset to %@ default": "Auf %@-Standard zurücksetzen",
    "Resume": "Fortsetzen",
    "Reveal sensitive content": "Sensible Inhalte anzeigen",
    "Rich text": "Rich Text",
    "Save hex (#RRGGBB)": "Hex speichern (#RRGGBB)",
    "Save named colors (red, blue…)": "Benannte Farben speichern (red, blue…)",
    "Save rgb(...)": "rgb(...) speichern",
    "Save rgba(...)": "rgba(...) speichern",
    "Save tuples (0, 0, 0)": "Tupel speichern (0, 0, 0)",
    "Screenshots": "Screenshots",
    "Select a category": "Kategorie auswählen",
    "Sensitive content": "Sensible Inhalte",
    "Show %lld clippings in menu bar": "%lld Ausschnitte in der Menüleiste anzeigen",
    "Show %lld colors in menu bar": "%lld Farben in der Menüleiste anzeigen",
    "Show %lld favorites in menu bar": "%lld Favoriten in der Menüleiste anzeigen",
    "Show %lld screenshots in menu bar": "%lld Screenshots in der Menüleiste anzeigen",
    "Stop ignoring %@": "%@ nicht mehr ignorieren",
    "Support": "Support",
    "System": "System",
    "Terms of Use": "Nutzungsbedingungen",
    "Text": "Text",
    "Theme color": "Akzentfarbe",
    "Theme color %@": "Akzentfarbe %@",
    "These types are detected and blurred in the screenshot editor.": "Diese Typen werden erkannt und im Screenshot-Editor unscharf gemacht.",
    "These types stay hidden until unlocked with password or Touch ID.": "Diese Typen bleiben verborgen, bis sie mit Passwort oder Touch ID entsperrt werden.",
    "This cannot be undone.": "Das kann nicht rückgängig gemacht werden.",
    "Tokens": "Tokens",
    "Turn Off": "Ausschalten",
    "URLs": "URLs",
    "Until next session": "Bis zur nächsten Sitzung",
    "Used when you click a color in history or pick from the color panel. Also controls how colors are shown in lists.": "Wird verwendet, wenn Sie eine Farbe in der Historie anklicken oder im Farbpanel wählen. Steuert auch die Anzeige in Listen.",
    "We can’t copy this kind of content. Pornography and sexual material aren’t allowed.": "Diese Art von Inhalt kann nicht kopiert werden. Pornografie und sexuelles Material sind nicht erlaubt.",
    "What is sensitive content": "Was sind sensible Inhalte",
    "While paused, new clipboard or screenshot captures are not saved. Permanent pause survives relaunch until you resume.": "Während der Pause werden neue Zwischenablage- oder Screenshot-Erfassungen nicht gespeichert. Eine dauerhafte Pause bleibt nach Neustart bis zum Fortsetzen bestehen.",
    "You can change this anytime in Settings. The app will not open at login unless you choose to.": "Sie können dies jederzeit in den Einstellungen ändern. Die App startet beim Anmelden nur, wenn Sie das wählen.",
    "clippings": "Ausschnitte",
    "passwords, IBANs, cards, API keys, OTPs, emails, phones, and amounts": "Passwörter, IBANs, Karten, API-Schlüssel, OTPs, E-Mails, Telefone und Beträge",
    "screenshots": "Screenshots",
}


def english_of(key: str, entry: dict) -> str:
    locs = entry.get("localizations") or {}
    en = ((locs.get("en") or {}).get("stringUnit") or {}).get("value")
    return en if en is not None else key


def apply_de(path: Path) -> tuple[int, list[str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    strings = data.setdefault("strings", {})
    updated = 0
    missing: list[str] = []
    for key, entry in strings.items():
        if key == "" and not entry:
            continue
        if not isinstance(entry, dict):
            entry = {}
            strings[key] = entry
        locs = entry.setdefault("localizations", {})
        src = english_of(key, entry)
        if not src:
            continue
        de = DE.get(src) or DE.get(key)
        if not de:
            # Keep technical / identical tokens
            if src in {"Hex", "RGB", "RGBA", "JSON", "OTPs", "IBANs", "PDFs", "URLs", "API keys", "Hashes", "Tokens", "Paint Buddy"}:
                de = src
            else:
                missing.append(f"{path.name}:{key!r} en={src!r}")
                continue
        locs["de"] = {"stringUnit": {"state": "translated", "value": de}}
        # Ensure English exists when key was empty stub
        if "en" not in locs and key:
            locs["en"] = {"stringUnit": {"state": "translated", "value": src if src else key}}
        if "extractionState" not in entry and locs:
            entry["extractionState"] = "manual"
        updated += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return updated, missing


def main() -> None:
    targets = [
        ROOT / "paint-buddy/PaintBuddy/Resources/Localizable.xcstrings",
        ROOT / "shared-buddy/Sources/BuddyLocalization/Resources/Localizable.xcstrings",
    ]
    all_missing: list[str] = []
    for path in targets:
        n, missing = apply_de(path)
        print(f"{path.relative_to(ROOT)}: updated {n} keys")
        all_missing.extend(missing)
    if all_missing:
        print(f"MISSING {len(all_missing)}:")
        for m in all_missing:
            print(" ", m)
        raise SystemExit(1)
    print("OK")


if __name__ == "__main__":
    main()
