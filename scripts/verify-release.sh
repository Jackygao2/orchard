#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--require-publishable] <ContainerDesk-<version>-arm64.dmg>" >&2
}

require_publishable=0
if [[ $# -eq 2 && "$1" == "--require-publishable" ]]; then
    require_publishable=1
    shift
elif [[ $# -ne 1 ]]; then
    usage
    exit 2
fi
image=$1
if [[ ! -f "$image" ]]; then
    echo "Disk image not found: $image" >&2
    exit 1
fi
image=$(cd "$(dirname "$image")" && pwd -P)/$(basename "$image")
checksum="${image}.sha256"
if [[ ! -f "$checksum" ]]; then
    echo "SHA-256 sidecar not found: $checksum" >&2
    exit 1
fi
(cd "$(dirname "$image")" && shasum -a 256 -c "$(basename "$checksum")")
hdiutil verify "$image"

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
expected_background="$repo_root/assets/containerdesk-dmg/background.png"
expected_background_2x="$repo_root/assets/containerdesk-dmg/background@2x.png"
mount_point=$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-verify.XXXXXX")
attached=0
cleanup() {
    if [[ "$attached" == 1 ]]; then
        hdiutil detach "$mount_point" -quiet || true
    fi
    rmdir "$mount_point" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
hdiutil attach "$image" -readonly -noverify -nobrowse -noautoopen -mountpoint "$mount_point" >/dev/null
attached=1
app="$mount_point/ContainerDesk.app"
if [[ ! -d "$app" ]]; then
    echo "Disk image does not contain ContainerDesk.app at its root." >&2
    exit 1
fi
if [[ ! -L "$mount_point/Applications" || "$(readlink "$mount_point/Applications")" != "/Applications" ]]; then
    echo "Disk image is missing the /Applications shortcut." >&2
    exit 1
fi
if [[ ! -f "$mount_point/.background/background.png" || ! -f "$expected_background" ]] || ! cmp -s "$mount_point/.background/background.png" "$expected_background"; then
    echo "Disk image is missing its checked-in ContainerDesk background." >&2
    exit 1
fi
if [[ -f "$expected_background_2x" ]] && { [[ ! -f "$mount_point/.background/background@2x.png" ]] || ! cmp -s "$mount_point/.background/background@2x.png" "$expected_background_2x"; }; then
    echo "Disk image is missing its checked-in 2x ContainerDesk background." >&2
    exit 1
fi
identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
minimum_os=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app/Contents/Info.plist")
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")
if [[ "$identifier" != "local.containerdesk" || "$executable" != "ContainerDesk" ]]; then
    echo "Unexpected app identity: identifier=$identifier executable=$executable" >&2
    exit 1
fi
if [[ "$minimum_os" != "26.0" ]]; then
    echo "Expected minimum macOS 26.0; found: $minimum_os" >&2
    exit 1
fi
binary="$app/Contents/MacOS/$executable"
architectures=$(lipo -archs "$binary")
if [[ "$architectures" != "arm64" ]]; then
    echo "Expected an arm64-only app; found: $architectures" >&2
    exit 1
fi

signature_info=$(codesign -dv --verbose=4 "$app" 2>&1 || true)
if codesign --verify --deep --strict --verbose=2 "$app" >/dev/null 2>&1; then
    signature_valid=1
else
    signature_valid=0
fi
if [[ "$signature_valid" == 1 ]]; then
    if grep -q 'Signature=adhoc' <<<"$signature_info"; then
        signature_state="ad-hoc (local development only)"
    elif grep -q 'Authority=Developer ID Application:' <<<"$signature_info"; then
        signature_state="Developer ID signed"
    else
        signature_state="signed; identity is not Developer ID"
    fi
else
    signature_state="invalid or absent"
fi
if grep -Eq 'flags=.*runtime|flags=0x10000' <<<"$signature_info"; then
    hardened_runtime="yes"
else
    hardened_runtime="no"
fi
if spctl --assess --type execute --verbose=2 "$app" >/dev/null 2>&1; then
    app_gatekeeper="accepted"
else
    app_gatekeeper="rejected"
fi
if xcrun stapler validate "$image" >/dev/null 2>&1; then
    stapled="yes"
else
    stapled="no"
fi

echo "Artifact: $image"
echo "SHA-256: verified"
echo "Bundle identifier: $identifier"
echo "Minimum macOS: $minimum_os"
echo "Architecture: $architectures"
echo "Applications shortcut: verified"
echo "DMG background: verified"
echo "Code signature: $signature_state"
echo "Hardened runtime: $hardened_runtime"
echo "App Gatekeeper assessment: $app_gatekeeper"
echo "Notarization ticket stapled: $stapled"

if [[ "$signature_valid" != 1 ]]; then
    echo "App signature verification failed." >&2
    exit 1
fi
if [[ "$require_publishable" == 1 ]]; then
    if [[ "$signature_state" != "Developer ID signed" || "$hardened_runtime" != "yes" || "$app_gatekeeper" != "accepted" || "$stapled" != "yes" ]]; then
        echo "Artifact is not publishable: Developer ID signing, hardened runtime, Gatekeeper acceptance and a stapled notarization ticket are required." >&2
        exit 1
    fi
    if ! spctl --assess --type open --context context:primary-signature --verbose=2 "$image"; then
        echo "Disk image Gatekeeper assessment failed." >&2
        exit 1
    fi
fi
