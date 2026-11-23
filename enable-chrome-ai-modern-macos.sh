#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"
LOCAL_STATE="$CHROME_DIR/Local State"
LAST_VERSION="$CHROME_DIR/Last Version"
BACKUP_ROOT="$SCRIPT_DIR/backups"
CHROME_PROCESS_RE='^/Applications/Google Chrome.app/Contents/MacOS/Google Chrome( |$)'

log() {
    printf '[INFO] %s\n' "$1"
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

chrome_is_running() {
    pgrep -f "$CHROME_PROCESS_RE" >/dev/null 2>&1
}

stop_chrome() {
    if ! chrome_is_running; then
        return
    fi

    log "Closing Google Chrome..."
    osascript -e 'tell application "Google Chrome" to quit' >/dev/null 2>&1 || true

    local attempt
    for attempt in {1..15}; do
        if ! chrome_is_running; then
            log "Google Chrome closed cleanly."
            return
        fi
        sleep 1
    done

    fail "Google Chrome did not exit after 15 seconds. Close it manually and rerun; no files were changed."
}

command -v jq >/dev/null 2>&1 || fail "jq is required."
[[ -f "$LOCAL_STATE" ]] || fail "Chrome Local State was not found."
[[ -f "$LAST_VERSION" ]] || fail "Chrome Last Version was not found."

jq empty "$LOCAL_STATE" || fail "Chrome Local State is not valid JSON."

chrome_version="$(tr -d '\r\n' < "$LAST_VERSION")"
[[ -n "$chrome_version" ]] || fail "Chrome version is empty."

active_profile="$(jq -r '.profile.last_used // .profile.last_active_profiles[0] // "Default"' "$LOCAL_STATE")"
preferences="$CHROME_DIR/$active_profile/Preferences"
[[ -f "$preferences" ]] || fail "Preferences not found for active profile: $active_profile"
jq empty "$preferences" || fail "Active profile Preferences is not valid JSON."

stop_chrome

timestamp="$(date +%Y%m%d%H%M%S)"
backup_dir="$BACKUP_ROOT/$timestamp"
mkdir -p "$backup_dir"
cp -p "$LOCAL_STATE" "$backup_dir/Local State"
cp -p "$preferences" "$backup_dir/Preferences"
printf '%s\n' "$active_profile" > "$backup_dir/profile_name"
printf '%s\n' "$chrome_version" > "$backup_dir/chrome_version"
ln -sfn "$backup_dir" "$BACKUP_ROOT/latest"
log "Backup created: $backup_dir"

local_state_tmp="${LOCAL_STATE}.modern-ai.tmp.$$"
preferences_tmp="${preferences}.modern-ai.tmp.$$"
cleanup() {
    rm -f "$local_state_tmp" "$preferences_tmp"
}
trap cleanup EXIT

cp -p "$LOCAL_STATE" "$local_state_tmp"
jq --arg version "$chrome_version" --arg profile "$active_profile" '
    .variations_country = "us"
    | .variations_permanent_consistency_country = [$version, "us"]
    | .variations_permanent_overridden_country = "us"
    | .variations_safe_seed_permanent_consistency_country = [$version, "us"]
    | .variations_safe_seed_session_consistency_country = "us"
    | .variations_safe_seed_locale = "en-US"
    | .profile.info_cache[$profile].is_glic_eligible = true
' "$LOCAL_STATE" > "$local_state_tmp"
jq empty "$local_state_tmp"

cp -p "$preferences" "$preferences_tmp"
jq '
    if (.glic | type) != "object" then .glic = {} else . end
    | if (.sync | type) != "object" then .sync = {} else . end
    | if (.browser | type) != "object" then .browser = {} else . end
    | .glic.previously_not_allowed = false
    | .glic.pinned_to_tabstrip = true
    | .sync.glic_rollout_eligibility = true
    | .browser.gemini_settings = 0
' "$preferences" > "$preferences_tmp"
jq empty "$preferences_tmp"

mv "$local_state_tmp" "$LOCAL_STATE"
mv "$preferences_tmp" "$preferences"
trap - EXIT

log "Patched Chrome $chrome_version profile: $active_profile"
log "Starting Chrome with country override and session-country filtering disabled..."
open -a "Google Chrome" --args \
    --variations-override-country=us \
    --disable-features=GlicUseSessionCountryForFiltering

log "Chrome launch requested. Restore with: $SCRIPT_DIR/restore-chrome-ai-modern-macos.sh"
