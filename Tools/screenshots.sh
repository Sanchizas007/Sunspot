#!/bin/bash
#
# Shoots the App Store screenshot set: every screen, every language, without a single tap.
#
#     Tools/screenshots.sh              # English, which is the set that goes to the store
#     Tools/screenshots.sh de fr        # the other two, if a listing ever wants them
#
# Frames land in screenshots/<language>/ at 1320x2868 — the 6.9" size App Store Connect
# asks for. That size is shot rather than any of the smaller ones because Apple accepts a
# single 6.9" set and scales it down itself, so it is the only set that has to exist.
#
# Nothing here touches the screen. The app seeds itself from a launch argument (see
# Sunspot/App/Demo.swift): the same garden, the same traced skyline, the same half past one
# in the afternoon, every time. That is the point — a set shot by hand cannot be retaken
# months later when a screen changes, because nobody remembers which spot it was.
set -euo pipefail

DEVICE="${SUNSPOT_DEVICE:-iPhone 17 Pro Max}"
BUNDLE="app.sunspot"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${SUNSPOT_DERIVED:-$ROOT/.build/screenshots}"
OUT="$ROOT/screenshots"

# In selling order rather than tab order. The number is the answer people came for; the sky
# is the only thing here nobody else does; the year and the planting list are what turn one
# answer into a reason to keep the app.
SCREENS=(today sky year plants map compare)

# What each frame is, in the filename, so that six months from now the folder can be opened
# and uploaded without opening a single image to work out which is which.
label() {
    case "$1" in
        today)   echo "the-answer-in-hours" ;;
        sky)     echo "trace-the-skyline" ;;
        year)    echo "when-full-sun-starts-and-ends" ;;
        plants)  echo "what-will-grow-here" ;;
        map)     echo "where-the-sun-comes-from" ;;
        compare) echo "which-spot-is-better" ;;
        *)       echo "$1" ;;
    esac
}

# English only by default. The app is translated into three languages and the store listing
# could carry a set for each, but one set is what is being submitted, and three sets is three
# times the work every time a screen moves. The other two are a command-line argument away —
# and they have already earned it: shooting the German set is what exposed five strings that
# were reaching German readers in English.
if [ $# -gt 0 ]; then LANGUAGES=("$@"); else LANGUAGES=(en); fi

# English is shot as en_GB rather than en_US, and not out of politeness. The status bar can
# only be overridden with a literal string that `simctl` zero-pads — ask for "1:30" and it
# renders "01:30" — so a 12-hour app clock can never be made to agree with it. en_GB runs the
# app on the same 24-hour clock as the other two, and the English garden is in London anyway.
locale_id() {
    case "$1" in
        de) echo "de_DE" ;;
        fr) echo "fr_FR" ;;
        *)  echo "en_GB" ;;
    esac
}

# The clock in the status bar, matching the moment the app itself is frozen at, so the two
# halves of the same photograph do not disagree.
STATUS_TIME="13:30"

UDID=$(xcrun simctl list devices available \
    | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "Нет доступного симулятора «$DEVICE»." >&2; exit 1; }
echo "==> $DEVICE  $UDID"

echo "==> Сборка"
xcodebuild -project "$ROOT/Sunspot.xcodeproj" -scheme Sunspot -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" build >/dev/null

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Sunspot.app"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl install "$UDID" "$APP"

# Refused rather than granted, and refused rather than left to prompt. A screenshot run has
# its spots seeded already and never asks the device where it is — but the app builds a
# `CLLocationManager` at startup regardless, and with permission in place that alone is enough
# to put the "recently used location" arrow in the status bar of every frame. On a store
# listing for a garden app that arrow reads as tracking. Refusing removes it and can put no
# dialog across a frame either, which leaving it unanswered could.
xcrun simctl privacy "$UDID" revoke location "$BUNDLE" 2>/dev/null || true

# A full battery and a carrier that is not called "Simulator". Apple rejects sets that show
# the simulator's own status bar.
# `discharging` at a hundred per cent rather than `charged`: the latter draws a lightning bolt
# through the battery, which reads as a phone on a cable rather than a phone in a garden.
# The operator name is emptied because the simulator's is literally "Simulator".
xcrun simctl status_bar "$UDID" override --time "$STATUS_TIME" \
    --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 --operatorName ""

# Reports whether a frame actually caught the screen, and flattens it to RGB on the way past:
# App Store Connect rejects an alpha channel and then blames the dimensions for it.
#
# A fixed sleep is not enough and never was. The first launch after an install is slow, the
# year is worked out off the main actor, and the comparison spends a moment on both spots
# before it has anything to draw. Waiting longer only moves the race. So the frame is
# measured — and measured per screen, because the two ways these come out wrong do not look
# alike: an empty list is flat, while the Sky screen has a gradient behind it that is not
# flat at all and would pass a plain variance check with the overlay missing entirely.
verify() {
    python3 - "$1" "$2" <<'CHECK'
import sys
from PIL import Image, ImageStat

screen, path = sys.argv[1], sys.argv[2]
try:
    im = Image.open(path).convert("RGB")
except Exception:
    sys.exit(1)
w, h = im.size

# The status bar and the tab bar carry content even on an empty screen; neither is evidence.
body = im.crop((0, int(h * 0.12), w, int(h * 0.88)))
if ImageStat.Stat(body.convert("L")).stddev[0] < 8:
    sys.exit(1)

pixels = list(body.getdata())

def share(test):
    return sum(1 for p in pixels if test(p)) / len(pixels)

if screen == "sky":
    # The sun disc and its arc. This is the check that matters: the overlay is the whole
    # screen, it is drawn only once the projection resolves, and when it does not the
    # gradient behind it still looks like a photograph of a sky.
    yellow = share(lambda p: p[0] > 190 and p[1] > 150 and p[2] < 120)
    cyan = share(lambda p: p[2] > 170 and p[1] > 150 and p[0] < 140)
    if yellow < 0.001:
        print("нет солнца и дуги", file=sys.stderr); sys.exit(1)
    if cyan < 0.0005:
        print("нет обведённой линии горизонта", file=sys.stderr); sys.exit(1)
elif screen == "map":
    # Texture rather than colour. Colour was the first thing tried and it rejected a
    # perfectly good frame: Berlin in leafless imagery, seen over a railway cutting, is
    # almost entirely grey and brown. Unloaded tiles are flat, which is a different
    # thing altogether and what actually needs catching.
    tiles = im.crop((0, int(h * 0.35), w, int(h * 0.75))).convert("L")
    if ImageStat.Stat(tiles).stddev[0] < 20:
        print("плитки карты не загрузились", file=sys.stderr); sys.exit(1)

im.save(path, "PNG", dpi=(72, 72))
CHECK
}

# Launches the app straight onto one screen and shoots it, retrying until the frame holds up.
capture() {
    local screen="$1" file="$2" attempt
    for attempt in 1 2 3 4 5 6; do
        xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
        xcrun simctl launch "$UDID" "$BUNDLE" \
            -SunspotDemoData -SunspotDemoScreen "$screen" \
            -AppleLanguages "($language)" -AppleLocale "$(locale_id "$language")" >/dev/null
        sleep $((2 + attempt))
        xcrun simctl io "$UDID" screenshot --type png "$file" 2>/dev/null
        if verify "$screen" "$file"; then
            # The path as it sits in the folder, not the language plus a bare name: the
            # paywall frame lives beside the language folders rather than inside one, and a
            # log line saying otherwise is a wrong answer to "where did it go".
            echo "    ${file#"$OUT"/}"
            return 0
        fi
    done
    echo "    !! $language/$(basename "$file") не снялся за шесть попыток" >&2
    return 1
}

bad=0

for language in "${LANGUAGES[@]}"; do
    mkdir -p "$OUT/$language"

    index=1
    for screen in "${SCREENS[@]}"; do
        file=$(printf "%s/%s/%02d-%s-%s.png" \
            "$OUT" "$language" "$index" "$screen" "$(label "$screen")")
        capture "$screen" "$file" || bad=$((bad + 1))
        index=$((index + 1))
    done

    # Every frame in a set must differ from every other one. This catches the failure the
    # per-frame check cannot see: a launch argument that stopped selecting anything, leaving
    # six perfectly good photographs of the same screen.
    python3 - "$OUT/$language" <<'DISTINCT' || bad=$((bad + 1))
import sys, hashlib
from pathlib import Path
seen = {}
for file in sorted(Path(sys.argv[1]).glob("[0-9]*.png")):
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    if digest in seen:
        print(f"    !! {file.name} совпадает с {seen[digest]} — экран не переключился",
              file=sys.stderr)
        sys.exit(1)
    seen[digest] = file.name
DISTINCT
done

# The paywall, for the review screenshot the in-app purchase itself needs. Deliberately not
# numbered and not part of any language set: it carries a price, and a store listing that
# shows one needs a fresh review every time the price moves.
if [[ " ${LANGUAGES[*]} " == *" en "* ]]; then
    language=en
    capture paywall "$OUT/in-app-purchase-review-screenshot.png" || bad=$((bad + 1))
fi

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

# App Store Connect rejects a PNG with an alpha channel, and blames the dimensions when it
# does. Every frame is flattened as it is taken, so this should never fire — which is exactly
# why it is here: the flattening is one line inside a function that does four other things,
# and a set that has quietly grown a transparency layer looks identical until it is refused.
python3 - "$OUT" <<'FINAL' || bad=$((bad + 1))
import sys
from pathlib import Path
from PIL import Image

sizes, problems = set(), []
files = sorted(Path(sys.argv[1]).rglob("*.png"))
for file in files:
    im = Image.open(file)
    if im.mode != "RGB":
        problems.append(f"    !! {file.name}: режим {im.mode}, а нужен RGB без альфа-канала")
    sizes.add(im.size)
if len(sizes) > 1:
    problems.append(f"    !! кадры разного размера: {sorted(sizes)}")
if problems:
    print("\n".join(problems), file=sys.stderr); sys.exit(1)
width, height = sizes.pop() if sizes else (0, 0)
print(f"==> {len(files)} кадров, {width}x{height}, без альфа-канала")
FINAL

if [ "$bad" -gt 0 ]; then
    echo "==> Кадров с проблемами: $bad. Такой набор в стор не отправлять." >&2
    exit 1
fi
echo "==> Готово: $OUT"
