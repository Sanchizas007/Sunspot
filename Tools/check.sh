#!/bin/zsh
# Общая проверка после каждой фичи: движок, сборка, тесты приложения.
# Прогонять до коммита — конфликты между фичами всплывают здесь, а не в сторе.
#
#   ./Tools/check.sh
#
cd "$(dirname "$0")/.."
LOG=$(mktemp -t sunspot-check)
FAILED=()

step() { print -n "── $1 "; }
ok()   { print "✅"; }
bad()  { print "❌"; FAILED+=("$1"); }

step "движок SolarCore      "
if (cd Packages/SolarCore && swift test) > "$LOG" 2>&1; then
  print -n "$(grep -oE 'Test run with [0-9]+ tests' "$LOG" | tail -1)  "; ok
else
  bad "SolarCore"; grep -E "error:|✘" "$LOG" | head -10
fi

step "сборка приложения     "
if xcodebuild -project Sunspot.xcodeproj -scheme Sunspot \
     -destination 'generic/platform=iOS Simulator' build > "$LOG" 2>&1; then
  WARNINGS=$(grep -c "warning:" "$LOG")
  print -n "предупреждений: $WARNINGS  "; ok
else
  bad "сборка"; grep -E "error:" "$LOG" | sort -u | head -10
fi

step "тесты приложения      "
UDID=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for rt in sorted(d, reverse=True):
    if 'iOS' not in rt: continue
    for dev in d[rt]:
        if 'iPhone' in dev['name']: print(dev['udid']); sys.exit()
")
if [[ -z "$UDID" ]]; then
  print "⚠ нет симулятора iPhone — пропущено"
elif xcodebuild -project Sunspot.xcodeproj -scheme Sunspot \
       -destination "id=$UDID" test > "$LOG" 2>&1; then
  print -n "$(grep -oE 'Test run with [0-9]+ tests' "$LOG" | tail -1)  "; ok
else
  bad "тесты приложения"; grep -E "error:|✘|failed" "$LOG" | sort -u | head -10
fi

rm -f "$LOG"
print ""
if (( ${#FAILED} == 0 )); then
  print "✅ общая проверка пройдена"
else
  print "❌ провалено: ${(j:, :)FAILED}"
  exit 1
fi
