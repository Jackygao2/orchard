#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <ContainerDesk-<version>-arm64.dmg> [--install-root <path>]" >&2
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
    usage
    exit 2
fi
image=$1
shift
install_root=/Applications
if [[ $# -gt 0 ]]; then
    if [[ $# -ne 2 || "$1" != "--install-root" ]]; then
        usage
        exit 2
    fi
    install_root=$2
fi
if [[ ! -f "$image" ]]; then
    echo "Disk image not found: $image" >&2
    exit 1
fi
if [[ "$install_root" != /* ]]; then
    echo "Install root must be an absolute path." >&2
    exit 2
fi
install_root=$(mkdir -p "$install_root" && cd "$install_root" && pwd -P)
app_path="$install_root/ContainerDesk.app"
if [[ -e "$app_path" || -L "$app_path" ]]; then
    echo "Refusing to overwrite existing app: $app_path" >&2
    exit 1
fi
if pgrep -x ContainerDesk >/dev/null 2>&1; then
    echo "A ContainerDesk process is already running; refusing to confuse it with this launch check." >&2
    exit 1
fi

mount_point=$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-install.XXXXXX")
attached=0
launched_pid=
executable_path=
is_launched_app_running() {
    [[ -n "$launched_pid" && -n "$executable_path" ]] || return 1
    kill -0 "$launched_pid" 2>/dev/null || return 1
    lsof -a -p "$launched_pid" -d txt -Fn 2>/dev/null | grep -Fq "$app_path/Contents/MacOS/ContainerDesk"
}
cleanup() {
    if is_launched_app_running; then
        kill -TERM "$launched_pid" 2>/dev/null || true
        for _ in {1..15}; do
            is_launched_app_running || break
            sleep 1
        done
        if is_launched_app_running; then
            kill -KILL "$launched_pid" 2>/dev/null || true
        fi
    fi
    if [[ "$attached" == 1 ]]; then
        hdiutil detach "$mount_point" -quiet || true
    fi
    rmdir "$mount_point" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
hdiutil attach "$image" -readonly -noverify -nobrowse -noautoopen -mountpoint "$mount_point" >/dev/null
attached=1
if [[ ! -d "$mount_point/ContainerDesk.app" ]]; then
    echo "Disk image does not contain ContainerDesk.app at its root." >&2
    exit 1
fi
ditto "$mount_point/ContainerDesk.app" "$app_path"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_path/Contents/Info.plist")
if [[ "$bundle_id" != "local.containerdesk" || "$executable" != "ContainerDesk" ]]; then
    echo "Installed app has an unexpected bundle identity." >&2
    exit 1
fi
hdiutil detach "$mount_point" -quiet
attached=0

open -n "$app_path"
for _ in {1..30}; do
    candidate_pid=$(pgrep -x ContainerDesk | head -n 1 || true)
    if [[ -n "$candidate_pid" ]]; then
        candidate_path=$(lsof -a -p "$candidate_pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | grep -F "$app_path/Contents/MacOS/ContainerDesk" | head -n 1 || true)
        if [[ -n "$candidate_path" ]]; then
            launched_pid=$candidate_pid
            executable_path=$candidate_path
            break
        fi
    fi
    sleep 1
done
if [[ -z "$launched_pid" || -z "$executable_path" ]]; then
    echo "ContainerDesk did not launch from the requested install root: $app_path" >&2
    exit 1
fi
echo "Launch verified from: $executable_path"
echo "Runtime install/start was not performed."
kill -TERM "$launched_pid"
for _ in {1..15}; do
    is_launched_app_running || break
    sleep 1
done
if is_launched_app_running; then
    echo "ContainerDesk did not exit after SIGTERM; stopping only PID $launched_pid." >&2
    kill -KILL "$launched_pid" 2>/dev/null || true
    exit 1
fi
launched_pid=
