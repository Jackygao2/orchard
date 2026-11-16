#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <ContainerDesk.app> <version>" >&2
}

if [[ $# -ne 2 ]]; then
    usage
    exit 2
fi
app_source=$1
version=$2
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
    echo "Version must be a safe dotted version such as 1.0.0 or 1.0.0-rc1." >&2
    exit 2
fi
if [[ ! -d "$app_source" || "$(basename "$app_source")" != "ContainerDesk.app" ]]; then
    echo "Expected an existing ContainerDesk.app bundle." >&2
    exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
background="$repo_root/assets/containerdesk-dmg/background.png"
if [[ ! -f "$background" ]]; then
    echo "Missing ContainerDesk DMG background: $background" >&2
    exit 1
fi
build_dir=${CONTAINERDESK_BUILD_DIR:-"$repo_root/build"}
mkdir -p "$build_dir"
build_dir=$(cd "$build_dir" && pwd -P)
if [[ "$build_dir" == "/" ]]; then
    echo "Refusing to use the filesystem root as the build directory." >&2
    exit 2
fi

image_name="ContainerDesk-$version-arm64.dmg"
image_path="$build_dir/$image_name"
checksum_path="$image_path.sha256"
rw_image="$build_dir/.ContainerDesk-$version-arm64-$$.rw.dmg"
stage=$(mktemp -d "$build_dir/.containerdesk-dmg-stage.XXXXXX")
mount_point=$(mktemp -d "$build_dir/.containerdesk-dmg-mount.XXXXXX")
attached=0
cleanup() {
    if [[ "$attached" == 1 ]]; then
        hdiutil detach "$mount_point" -quiet || true
    fi
    rm -rf -- "$stage" "$mount_point" "$rw_image"
}
trap cleanup EXIT INT TERM

ditto "$app_source" "$stage/ContainerDesk.app"
ln -s /Applications "$stage/Applications"
mkdir -p "$stage/.background"
cp "$background" "$stage/.background/background.png"
if [[ -f "$repo_root/assets/containerdesk-dmg/background@2x.png" ]]; then
    cp "$repo_root/assets/containerdesk-dmg/background@2x.png" "$stage/.background/background@2x.png"
fi
hdiutil create -srcfolder "$stage" -fs APFS -volname ContainerDesk -format UDRW "$rw_image"
hdiutil attach "$rw_image" -readwrite -noverify -nobrowse -noautoopen -mountpoint "$mount_point"
attached=1

escaped_mount=${mount_point//\\/\\\\}
escaped_mount=${escaped_mount//\"/\\\"}
osascript <<APPLESCRIPT
tell application "Finder"
    set imageFolder to POSIX file "$escaped_mount" as alias
    open imageFolder
    delay 1
    set containerWindow to front Finder window
    set current view of containerWindow to icon view
    set toolbar visible of containerWindow to false
    set statusbar visible of containerWindow to false
    set bounds of containerWindow to {120, 120, 780, 560}
    set viewOptions to icon view options of containerWindow
    set icon size of viewOptions to 96
    set arrangement of viewOptions to not arranged
    set background picture of viewOptions to (POSIX file "$escaped_mount/.background/background.png") as alias
    set position of item "ContainerDesk.app" of containerWindow to {155, 225}
    set position of item "Applications" of containerWindow to {505, 225}
    delay 2
    close containerWindow
end tell
APPLESCRIPT
hdiutil detach "$mount_point" -quiet
attached=0
rm -f -- "$image_path" "$checksum_path"
hdiutil convert "$rw_image" -format UDZO -imagekey zlib-level=9 -o "$image_path"
(cd "$build_dir" && shasum -a 256 "$image_name" > "$image_name.sha256")
echo "Created $image_path and $checksum_path"
