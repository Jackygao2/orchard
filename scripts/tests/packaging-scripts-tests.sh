#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-packaging-tests.XXXXXX")
trap 'rm -rf -- "$tmp_root"' EXIT INT TERM

expect_failure() {
    local label=$1
    local expected=$2
    shift 2
    local output="$tmp_root/output"
    if "$@" >"$output" 2>&1; then
        echo "FAIL: $label unexpectedly succeeded" >&2
        cat "$output" >&2
        return 1
    fi
    if ! grep -Fq "$expected" "$output"; then
        echo "FAIL: $label did not report '$expected'" >&2
        cat "$output" >&2
        return 1
    fi
    echo "PASS: $label"
}

expect_failure "build script rejects unknown option" "Usage:" "$repo_root/scripts/build-app.sh" --unknown
if [[ ! -f "$repo_root/Config/Signing.xcconfig" ]]; then
    expect_failure "signed build explains missing local signing config" "Signed build unavailable" env "CONTAINERDESK_BUILD_DIR=$tmp_root/signed-build" "$repo_root/scripts/build-app.sh" --signed
fi
expect_failure "DMG script rejects path-like version" "safe dotted version" "$repo_root/scripts/make-dmg.sh" /missing/ContainerDesk.app ../1.0.0
expect_failure "DMG script rejects missing app" "Expected an existing ContainerDesk.app" "$repo_root/scripts/make-dmg.sh" /missing/ContainerDesk.app 1.0.0
expect_failure "verifier rejects missing disk image" "Disk image not found" "$repo_root/scripts/verify-release.sh" "$tmp_root/missing.dmg"
touch "$tmp_root/fake.dmg"
expect_failure "install script requires absolute root" "Install root must be an absolute path" "$repo_root/scripts/install-and-launch-test.sh" "$tmp_root/fake.dmg" --install-root relative

mkdir -p "$tmp_root/installed/ContainerDesk.app"
expect_failure "install script protects existing app" "Refusing to overwrite existing app" "$repo_root/scripts/install-and-launch-test.sh" "$tmp_root/fake.dmg" --install-root "$tmp_root/installed"

for script in build-app.sh make-dmg.sh verify-release.sh install-and-launch-test.sh; do
    bash -n "$repo_root/scripts/$script"
done
echo "PASS: all packaging scripts pass bash -n"
