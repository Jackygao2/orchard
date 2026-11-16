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

# Exercise the public build-script path with a tiny fake archive so the signing
# mode can be checked without spending time compiling the app.
mock_bin="$tmp_root/mock-bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/xcodebuild" <<'STUB'
#!/bin/bash
set -euo pipefail
archive_path=
while (($#)); do
    if [[ "$1" == "-archivePath" ]]; then
        shift
        archive_path=$1
    fi
    shift
done
mkdir -p "$archive_path/Products/Applications/ContainerDesk.app/Contents/MacOS"
printf '#!/bin/sh\nexit 0\n' > "$archive_path/Products/Applications/ContainerDesk.app/Contents/MacOS/ContainerDesk"
chmod +x "$archive_path/Products/Applications/ContainerDesk.app/Contents/MacOS/ContainerDesk"
STUB
cat > "$mock_bin/codesign" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" > "$PACKAGING_CODESIGN_LOG"
STUB
cat > "$mock_bin/lipo" <<'STUB'
#!/bin/bash
[[ "${1:-}" == "-archs" ]] || exit 1
echo arm64
STUB
chmod +x "$mock_bin/xcodebuild" "$mock_bin/codesign" "$mock_bin/lipo"
codesign_log="$tmp_root/codesign.args"
PATH="$mock_bin:$PATH" PACKAGING_CODESIGN_LOG="$codesign_log" \
    CONTAINERDESK_BUILD_DIR="$tmp_root/unsigned-build" "$repo_root/scripts/build-app.sh" >"$tmp_root/unsigned-build.log" 2>&1
if ! grep -Fq -- "--sign -" "$codesign_log"; then
    echo "FAIL: unsigned local build did not use an ad-hoc signature" >&2
    cat "$codesign_log" >&2
    exit 1
fi
if grep -Fq -- "--options runtime" "$codesign_log"; then
    echo "FAIL: unsigned local build enabled Hardened Runtime" >&2
    cat "$codesign_log" >&2
    exit 1
fi
echo "PASS: unsigned local build uses ad-hoc signing without Hardened Runtime"

for script in build-app.sh make-dmg.sh verify-release.sh install-and-launch-test.sh; do
    bash -n "$repo_root/scripts/$script"
done
echo "PASS: all packaging scripts pass bash -n"
