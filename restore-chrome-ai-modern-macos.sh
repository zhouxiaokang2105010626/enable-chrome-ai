#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"
LOCAL_STATE="$CHROME_DIR/Local State"
BACKUP_ROOT="$SCRIPT_DIR/backups"
CHROME_PROCESS_RE='^/Applications/Google Chrome.app/Contents/MacOS/Google Chrome( |$)'
backup_dir="${1:-$BACKUP_ROOT/latest}"

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

chrome_is_running() {
    pgrep -f "$CHROME_PROCESS_RE" >/dev/null 2>&1
}

[[ -d "$backup_dir" ]] || fail "Backup directory not found: $backup_dir"
[[ -f "$backup_dir/Local State" ]] || fail "Backup Local State is missing."
[[ -f "$backup_dir/Preferences" ]] || fail "Backup Preferences is missing."
[[ -f "$backup_dir/profile_name" ]] || fail "Backup profile name is missing."

jq empty "$backup_dir/Local State" || fail "Backup Local State is invalid."
jq empty "$backup_dir/Preferences" || fail "Backup Preferences is invalid."

profile_name="$(tr -d '\r\n' < "$backup_dir/profile_name")"
preferences="$CHROME_DIR/$profile_name/Preferences"

if chrome_is_running; then
    printf '[INFO] Closing Google Chrome...\n'
    osascript -e 'tell application "Google Chrome" to quit' >/dev/null 2>&1 || true
    for attempt in {1..15}; do
        if ! chrome_is_running; then
            break
        fi
        sleep 1
    done
fi

chrome_is_running && fail "Google Chrome did not exit. Close it manually and rerun."

timestamp="$(date +%Y%m%d%H%M%S)"
pre_restore="$BACKUP_ROOT/pre-restore-$timestamp"
mkdir -p "$pre_restore"
[[ -f "$LOCAL_STATE" ]] && cp -p "$LOCAL_STATE" "$pre_restore/Local State"
[[ -f "$preferences" ]] && cp -p "$preferences" "$pre_restore/Preferences"
printf '%s\n' "$profile_name" > "$pre_restore/profile_name"

cp -p "$backup_dir/Local State" "$LOCAL_STATE"
cp -p "$backup_dir/Preferences" "$preferences"

printf '[INFO] Restored backup: %s\n' "$backup_dir"
printf '[INFO] Pre-restore state saved: %s\n' "$pre_restore"
open -a "Google Chrome"
