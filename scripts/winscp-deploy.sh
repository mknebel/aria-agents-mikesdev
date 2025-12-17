#!/bin/bash
# winscp-deploy.sh - Headless WinSCP deployment (no prompts, no waiting)
# Usage: winscp-deploy.sh <site|connection> [local-base] [remote-base] <file1> [file2] ...
#
# Sites (auto-resolve from ~/.claude/config/deploy-sites.json):
#   lyk-admin    → mpk-admin@LaunchYourKid.com
#   lyk-register → mpk-register@launchyourkid.com
#
# Or use raw WinSCP session name with explicit paths.

set -e

source ~/.claude/scripts/aria-config.sh 2>/dev/null || true

WINSCP="/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"
[[ ! -f "$WINSCP" ]] && WINSCP="/mnt/c/Program Files/WinSCP/WinSCP.com"
[[ ! -f "$WINSCP" ]] && { echo "ERROR: WinSCP not found"; exit 1; }

CONFIG="$HOME/.claude/config/deploy-sites.json"

# WinSCP.ini location (Windows path for WinSCP.com)
WINSCP_INI="G:\\My Drive\\WinSCP\\WinSCP.ini"

# Resolve site alias
resolve_site() {
    local site="$1"
    if [[ -f "$CONFIG" ]] && command -v jq >/dev/null; then
        local session=$(jq -r ".sites[\"$site\"].winscp_session // empty" "$CONFIG" 2>/dev/null)
        if [[ -n "$session" ]]; then
            echo "$session"
            return 0
        fi
    fi
    echo "$site"
}

get_site_path() {
    local site="$1" field="$2"
    [[ -f "$CONFIG" ]] && jq -r ".sites[\"$site\"].$field // empty" "$CONFIG" 2>/dev/null
}

# Parse args
SITE="$1"
shift || { echo "Usage: winscp-deploy.sh <site> <file1> [file2] ..."; exit 1; }

# Check if site alias exists
LOCAL_BASE=$(get_site_path "$SITE" "local_base")
REMOTE_BASE=$(get_site_path "$SITE" "remote_base")
HOSTKEY=$(get_site_path "$SITE" "hostkey")
CONNECTION=$(resolve_site "$SITE")

# If no site config, expect explicit paths
if [[ -z "$LOCAL_BASE" ]]; then
    LOCAL_BASE="$1"
    REMOTE_BASE="$2"
    shift 2 || { echo "ERROR: No site config for '$SITE' - provide local/remote paths"; exit 1; }
fi

[[ $# -eq 0 ]] && { echo "ERROR: No files specified"; exit 1; }

# Temp files (Windows paths for WinSCP)
TEMP_DIR="/mnt/c/temp/aria-winscp"
mkdir -p "$TEMP_DIR" 2>/dev/null
SCRIPT_FILE="$TEMP_DIR/winscp-$$.txt"
LOG_FILE="$TEMP_DIR/winscp-$$.log"
# Convert to Windows paths for WinSCP
SCRIPT_FILE_WIN="C:\\temp\\aria-winscp\\winscp-$$.txt"
LOG_FILE_WIN="C:\\temp\\aria-winscp\\winscp-$$.log"

echo "Deploy: $SITE → $CONNECTION"
echo "Files: $#"

# Generate script
HOSTKEY_OPT=""
[[ -n "$HOSTKEY" ]] && HOSTKEY_OPT=" -hostkey=\"$HOSTKEY\""

cat > "$SCRIPT_FILE" << SCRIPT
option batch abort
option confirm off
option transfer binary
open "$CONNECTION"$HOSTKEY_OPT
lcd "$LOCAL_BASE"
cd "$REMOTE_BASE"
SCRIPT

for FILE in "$@"; do
    echo "  $FILE"
    # Convert forward slashes to backslashes for local path (Windows)
    LOCAL_FILE=$(echo "$FILE" | sed 's|/|\\|g')
    echo "put \"$LOCAL_FILE\" \"$FILE\"" >> "$SCRIPT_FILE"
done

echo "exit" >> "$SCRIPT_FILE"

# Execute headless (no GUI, no prompts)
if "$WINSCP" /ini="$WINSCP_INI" /log="$LOG_FILE_WIN" /loglevel=0 /script="$SCRIPT_FILE_WIN" 2>/dev/null; then
    echo "OK: $# file(s) deployed"
    rm -f "$SCRIPT_FILE" "$LOG_FILE"
    exit 0
else
    echo "FAILED - see $LOG_FILE"
    tail -10 "$LOG_FILE" 2>/dev/null
    rm -f "$SCRIPT_FILE"
    exit 1
fi
