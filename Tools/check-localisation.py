#!/usr/bin/env python3
"""Checks that every string a person can see has a translation.

    python3 Tools/check-localisation.py

Localisation drifts silently: a new Text("...") builds, runs and ships, and simply appears in
English to a German reader. Nothing warns anybody. This walks the source, collects the keys
SwiftUI would look up, and fails if any of them is missing from the catalogue or untranslated.
"""

import json, re, sys
from pathlib import Path

LANGS = ("de", "fr")

def catalogue(path):
    data = json.loads(Path(path).read_text())
    return data["strings"]

def keys_in_source(paths):
    """The literals SwiftUI treats as localisation keys."""
    found = set()
    # Text("…"), Label("…", …), Button("…"), Section("…"), .navigationTitle("…") and friends.
    pattern = re.compile(
        r'(?:Text|Label|Button|Toggle|Section|navigationTitle|configurationDisplayName'
        r'|ContentUnavailableView|ProgressView|description|LocalizedStringKey)\(\s*"((?:[^"\\]|\\.)*)"'
    )
    localised = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')
    for root in paths:
        for file in Path(root).rglob("*.swift"):
            src = file.read_text()
            for match in list(pattern.finditer(src)) + list(localised.finditer(src)):
                raw = match.group(1)
                if not raw or raw.startswith(("app.", "group.", "sun-", "http")):
                    continue
                found.add(swiftui_key(raw))
    return found

def swiftui_key(raw):
    """Turns a Swift literal into the key SwiftUI looks up.

    Interpolations become format specifiers. Never positional ones, however many there are:
    that was assumed here once, the catalogue was written to match the assumption, and five
    strings reached German and French readers in English because the app was asking for
    `%lld … %@` while the catalogue answered to `%1$lld … %2$@`. Nothing failed, nothing
    warned; it took looking at a German screen. `LocalisationKeyTests` pins the real
    behaviour of both `LocalizedStringKey` and `String(localized:)` so this cannot drift back.
    """
    spans = []
    i = 0
    while i < len(raw) - 1:
        if raw[i] == "\\" and raw[i + 1] == "(":
            depth, j = 1, i + 2
            while j < len(raw) and depth:
                if raw[j] == "(": depth += 1
                elif raw[j] == ")": depth -= 1
                j += 1
            spans.append((i, j, raw[i + 2:j - 1]))
            i = j
        else:
            i += 1
    if not spans:
        return raw

    out, shift = raw, 0
    for start, end, expression in spans:
        # What the expression *returns*, not what words appear inside it: a call to
        # Format.time can mention defaultLeadMinutes in its arguments and still hand back
        # a string.
        text = expression.strip()
        produces_string = text.startswith(("Format.", "String(")) or text.endswith(".name")
        integral = not produces_string and (
            text.startswith("Int(") or text.endswith((".count", "Before", "Minutes"))
        )
        placeholder = "%lld" if integral else "%@"
        out = out[:start + shift] + placeholder + out[end + shift:]
        shift += len(placeholder) - (end - start)
    return out

def main():
    problems = []
    app = catalogue("Sunspot/Localizable.xcstrings")
    module = catalogue("Packages/SolarCore/Sources/SpotKit/Resources/Localizable.xcstrings")
    known = set(app) | set(module)

    for key in sorted(keys_in_source(["Sunspot", "SunspotWidgets"])):
        if key not in known:
            problems.append(f"нет в каталоге: {key!r}")

    for name, cat in (("приложения", app), ("модуля", module)):
        for key, entry in cat.items():
            for lang in LANGS:
                unit = entry.get("localizations", {}).get(lang, {}).get("stringUnit", {})
                if not unit.get("value"):
                    problems.append(f"каталог {name}: нет перевода на {lang}: {key!r}")
                elif unit.get("state") != "translated":
                    problems.append(f"каталог {name}: {lang} помечен как {unit.get('state')}: {key!r}")

    if problems:
        print("\n".join(problems[:25]))
        if len(problems) > 25:
            print(f"…и ещё {len(problems) - 25}")
        sys.exit(1)
    print(f"строк {len(known)}, языков {len(LANGS) + 1}, пропусков нет")

main()
