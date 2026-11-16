#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--signed]" >&2
    echo "Builds an arm64 Release app into build/ContainerDesk.app." >&2
}

mode=unsigned
if [[ $# -gt 1 ]]; then
    usage
    exit 2
fi
if [[ $# -eq 1 ]]; then
    if [[ "$1" != "--signed" ]]; then
        usage
        exit 2
    fi
    mode=signed
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
build_dir=${CONTAINERDESK_BUILD_DIR:-"$repo_root/build"}
mkdir -p "$build_dir"
build_dir=$(cd "$build_dir" && pwd -P)
if [[ "$build_dir" == "/" ]]; then
    echo "Refusing to use the filesystem root as the build directory." >&2
    exit 2
fi

if [[ "$mode" == signed ]]; then
    signing_file="$repo_root/Config/Signing.xcconfig"
    if [[ ! -f "$signing_file" ]]; then
        echo "Signed build unavailable: create Config/Signing.xcconfig from Config/Signing.example.xcconfig and configure a valid Developer ID identity." >&2
        exit 1
    fi
    team=$(awk -F= '/^[[:space:]]*CD_SIGNING_TEAM[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$signing_file")
    identity=$(awk -F= '/^[[:space:]]*CD_SIGNING_IDENTITY[[:space:]]*=/ {sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2); print $2; exit}' "$signing_file")
    if [[ ! "$team" =~ ^[A-Z0-9]{10}$ || "$identity" != "Developer ID Application"* || "$identity" == "Developer ID Application" ]]; then
        echo "Signed build unavailable: Config/Signing.xcconfig must contain a real 10-character team ID and a specific Developer ID Application identity." >&2
        exit 1
    fi
fi

archive_path="$build_dir/ContainerDesk.xcarchive"
app_path="$build_dir/ContainerDesk.app"
export_path="$build_dir/export"
rm -rf -- "$archive_path" "$app_path" "$export_path"

common_args=(
    -project "$repo_root/Orchard.xcodeproj"
    -scheme Orchard
    -configuration Release
    -destination 'generic/platform=macOS'
    -archivePath "$archive_path"
    -derivedDataPath "$build_dir/DerivedData"
    -clonedSourcePackagesDirPath "$build_dir/SourcePackages"
    ARCHS=arm64
    ONLY_ACTIVE_ARCH=NO
)

if [[ "$mode" == signed ]]; then
    xcodebuild -quiet archive "${common_args[@]}" CODE_SIGNING_ALLOWED=YES
    export_options="$build_dir/DeveloperIDExportOptions.plist"
    cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>signingStyle</key><string>manual</string>
<key>teamID</key><string>$team</string>
<key>signingCertificate</key><string>Developer ID Application</string>
</dict></plist>
PLIST
    xcodebuild -quiet -exportArchive -archivePath "$archive_path" -exportPath "$export_path" -exportOptionsPlist "$export_options"
    exported_app="$export_path/ContainerDesk.app"
    if [[ ! -d "$exported_app" ]]; then
        echo "Xcode export completed without producing ContainerDesk.app at the expected path." >&2
        exit 1
    fi
    ditto "$exported_app" "$app_path"
else
    xcodebuild -quiet archive "${common_args[@]}" CODE_SIGNING_ALLOWED=NO
    archived_app="$archive_path/Products/Applications/ContainerDesk.app"
    if [[ ! -d "$archived_app" ]]; then
        echo "Xcode archive completed without producing ContainerDesk.app." >&2
        exit 1
    fi
    ditto "$archived_app" "$app_path"
    codesign --force --deep --sign - --entitlements "$repo_root/Orchard/Orchard.entitlements" "$app_path"
fi

if [[ ! -x "$app_path/Contents/MacOS/ContainerDesk" ]]; then
    echo "Built app is missing its ContainerDesk executable." >&2
    exit 1
fi
architectures=$(lipo -archs "$app_path/Contents/MacOS/ContainerDesk")
if [[ "$architectures" != "arm64" ]]; then
    echo "Expected an arm64-only app; found: $architectures" >&2
    exit 1
fi
echo "Built $mode arm64 Release app: $app_path"
