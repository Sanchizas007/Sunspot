#!/bin/bash
#
# Builds the thing that goes to Apple, and optionally sends it.
#
#     Tools/release.sh              # archive and export a signed .ipa, stop there
#     Tools/release.sh --validate   # also ask App Store Connect whether it would take it
#     Tools/release.sh --upload     # also send it
#
# Validating and uploading need an App Store Connect API key, which is two public
# identifiers and one private file:
#
#     export ASC_KEY_ID=XXXXXXXXXX
#     export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#     # and the downloaded key at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8
#
# The key is made once at App Store Connect → Users and Access → Integrations → App Store
# Connect API, with the App Manager role. The .p8 downloads exactly once and cannot be
# downloaded again, which is worth knowing before closing the tab.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/.build/release-build"
ARCHIVE="$BUILD/Sunplot.xcarchive"
EXPORT="$BUILD/export"
TEAM="3M856J997X"

MODE="${1:-}"
mkdir -p "$BUILD"

# Every part of the store listing is settled somewhere else, but these two are settled here
# and a wrong one is discovered by Apple rather than by us.
VERSION=$(grep -oE 'MARKETING_VERSION = "[^"]+"' "$ROOT/Tools/make-project.py" | head -1 | cut -d'"' -f2)
NUMBER=$(grep -oE '"CURRENT_PROJECT_VERSION": "[^"]+"' "$ROOT/Tools/make-project.py" | head -1 | cut -d'"' -f4)
print() { printf "%s\n" "$1"; }

print "==> Sunplot $VERSION ($NUMBER)"
print "    App Store Connect отклоняет повторную выгрузку с тем же номером сборки."
print "    Новая попытка = новый номер: CURRENT_PROJECT_VERSION в Tools/make-project.py."
print ""

print "==> Общая проверка"
"$ROOT/Tools/check.sh"

print ""
print "==> Архив"
rm -rf "$ARCHIVE"
xcodebuild -project "$ROOT/Sunspot.xcodeproj" -scheme Sunspot -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE" \
    archive -allowProvisioningUpdates > "$BUILD/archive.log" 2>&1 \
    || { print "❌ архив не собрался, подробности в $BUILD/archive.log"; grep -E "error:" "$BUILD/archive.log" | sort -u | head -10; exit 1; }
print "    $ARCHIVE"

print ""
print "==> Экспорт под App Store"
cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
rm -rf "$EXPORT"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
    -exportOptionsPlist "$BUILD/ExportOptions.plist" -allowProvisioningUpdates \
    > "$BUILD/export.log" 2>&1 \
    || { print "❌ экспорт не прошёл, подробности в $BUILD/export.log"; exit 1; }

IPA=$(ls "$EXPORT"/*.ipa)
print "    $IPA  ($(du -h "$IPA" | cut -f1))"

# What actually went into the package, read out of the package rather than assumed. Every one
# of these has been wrong at least once in this project.
print ""
print "==> Что внутри"
rm -rf "$BUILD/inspect" && mkdir -p "$BUILD/inspect"
unzip -o -q "$IPA" -d "$BUILD/inspect"
APP=$(ls -d "$BUILD/inspect/Payload"/*.app)
plutil -p "$APP/Info.plist" | grep -E '"CFBundleIdentifier"|"CFBundleDisplayName"|"CFBundleShortVersionString"|"CFBundleVersion"' | sed 's/^/    /'
codesign -d --entitlements - "$APP" 2>/dev/null | grep -A 3 "application-groups" | grep "String" | sed 's/^.*String\] /    App Group: /'
codesign -d --entitlements - "$APP" 2>/dev/null | grep -A 2 "get-task-allow" | grep -q "false" \
    && print "    подпись дистрибуции ✅" || print "    🔴 подпись НЕ дистрибуционная — Apple такой пакет не примет"
MANIFESTS=$(find "$APP" -name "PrivacyInfo.xcprivacy" | wc -l | tr -d " ")
if [ "$MANIFESTS" = "2" ]; then
    print "    манифестов приватности: 2 ✅"
else
    print "    🔴 манифестов приватности: $MANIFESTS, а нужно два — приложение и виджет"
fi

if [ "$MODE" != "--validate" ] && [ "$MODE" != "--upload" ]; then
    print ""
    print "==> Готово. Дальше: --validate, потом --upload."
    exit 0
fi

: "${ASC_KEY_ID:?нужен ASC_KEY_ID — см. шапку файла}"
: "${ASC_ISSUER_ID:?нужен ASC_ISSUER_ID — см. шапку файла}"

if [ "$MODE" = "--validate" ]; then
    print ""
    print "==> Проверка на стороне Apple (ничего не отправляется)"
    xcrun altool --validate-app -f "$IPA" -t ios \
        --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    print "==> Принято бы. Теперь --upload."
else
    print ""
    print "==> Выгрузка в App Store Connect"
    xcrun altool --upload-app -f "$IPA" -t ios \
        --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    print ""
    print "==> Отправлено. Сборка появится в TestFlight через 5–30 минут, пока идёт обработка."
    print "    Пока обрабатывается — привязать её к версии на странице 1.0 нельзя."
fi
