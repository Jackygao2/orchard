#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <ContainerDesk-<version>-arm64.dmg>" >&2
    echo "Submits a Developer ID-signed DMG using the local notarytool Keychain profile, staples it, then verifies it." >&2
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

dmg=$1
if [[ ! -f "$dmg" ]]; then
    echo "Disk image not found: $dmg" >&2
    exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
signing_file="$repo_root/Config/Signing.xcconfig"
if [[ ! -f "$signing_file" ]]; then
    echo "Developer ID credentials are not configured: create the ignored Config/Signing.xcconfig from Config/Signing.example.xcconfig and install a Developer ID Application identity." >&2
    exit 1
fi

team=$(awk -F= '/^[[:space:]]*CD_SIGNING_TEAM[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$signing_file")
identity=$(awk -F= '/^[[:space:]]*CD_SIGNING_IDENTITY[[:space:]]*=/ {sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2); print $2; exit}' "$signing_file")
if [[ ! "$team" =~ ^[A-Z0-9]{10}$ || "$identity" != "Developer ID Application"* || "$identity" == "Developer ID Application" ]]; then
    echo "Developer ID credentials are not configured: Signing.xcconfig must contain a real team ID and a specific Developer ID Application identity." >&2
    exit 1
fi

identity_list=$(security find-identity -v -p codesigning 2>/dev/null || true)
if ! grep -Fq "\"$identity\"" <<<"$identity_list"; then
    echo "Developer ID identity is not available in the login Keychain." >&2
    exit 1
fi

profile=${CONTAINERDESK_NOTARY_PROFILE:-containerdesk-notary}
if ! xcrun notarytool history --keychain-profile "$profile" --output-format json >/dev/null 2>&1; then
    echo "Notarization Keychain profile '$profile' is unavailable. Create it with xcrun notarytool store-credentials; credentials are never read from this repository." >&2
    exit 1
fi

mount_point=$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-notarize.XXXXXX")
attached=0
cleanup() {
    if [[ "$attached" == 1 ]]; then
        hdiutil detach "$mount_point" -quiet || true
    fi
    rmdir "$mount_point" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

hdiutil attach "$dmg" -readonly -noverify -nobrowse -noautoopen -mountpoint "$mount_point" >/dev/null
attached=1
app_path="$mount_point/ContainerDesk.app"
if [[ ! -d "$app_path" ]]; then
    echo "Disk image does not contain ContainerDesk.app at its root." >&2
    exit 1
fi

if ! signature=$(codesign -dv --verbose=4 "$app_path" 2>&1); then
    echo "ContainerDesk.app does not have a verifiable code signature." >&2
    exit 1
fi
if ! grep -Fq "Authority=$identity" <<<"$signature" \
    || ! grep -Fq "TeamIdentifier=$team" <<<"$signature" \
    || ! grep -Eq 'flags=.*runtime' <<<"$signature"; then
    echo "ContainerDesk.app must be signed by the configured Developer ID identity with Hardened Runtime enabled." >&2
    exit 1
fi

hdiutil detach "$mount_point" -quiet
attached=0
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
"$repo_root/scripts/verify-release.sh" --require-publishable "$dmg"
