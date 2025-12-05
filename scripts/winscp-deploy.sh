#!/bin/bash
# winscp-deploy.sh - WinSCP deployment helper for Haiku agents
# Usage: winscp-deploy.sh <connection> <local-base> <remote-base> <file1> [file2] ...
#
# This script is called by Haiku agents with explicit parameters.
# No guessing - all values provided by Opus orchestrator.

set -e

# Source ARIA config for temp directories
source ~/.claude/scripts/aria-config.sh 2>/dev/null || true

WINSCP="/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"

# Check WinSCP exists
if [[ ! -f "$WINSCP" ]]; then
    WINSCP="/mnt/c/Program Files/WinSCP/WinSCP.com"
    if [[ ! -f "$WINSCP" ]]; then
        echo "ERROR: WinSCP not found"
        exit 1
    fi
fi

CONNECTION="$1"
LOCAL_BASE="$2"
REMOTE_BASE="$3"
shift 3

if [[ -z "$CONNECTION" || -z "$LOCAL_BASE" || -z "$REMOTE_BASE" || $# -eq 0 ]]; then
    echo "Usage: winscp-deploy.sh <connection> <local-base> <remote-base> <file1> [file2] ..."
    echo ""
    echo "Example:"
    echo "  winscp-deploy.sh lyk-production \\"
    echo "    /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin/ \\"
    echo "    /home/lyklive/public_html/admin/ \\"
    echo "    src/Controller/Admin/ItemsController.php \\"
    echo "    templates/Admin/Items/edit.php"
    exit 1
fi

# Use Windows-accessible project temp (WinSCP can't access WSL /tmp)
SCRIPT_FILE="$(aria_temp_file_win winscp-deploy-$$.txt)"
LOG_FILE="$(aria_temp_file_win winscp-deploy-$$.log)"

echo "═══════════════════════════════════════════════════════════════"
echo "WinSCP Deployment"
echo "═══════════════════════════════════════════════════════════════"
echo "Connection:  $CONNECTION"
echo "Local base:  $LOCAL_BASE"
echo "Remote base: $REMOTE_BASE"
echo "Files:       $#"
echo ""

# Generate WinSCP script
cat > "$SCRIPT_FILE" << SCRIPT
option batch abort
option confirm off
open $CONNECTION
lcd "$LOCAL_BASE"
cd "$REMOTE_BASE"
SCRIPT

# Add each file
for FILE in "$@"; do
    echo "  - $FILE"
    # Get directory part for remote mkdir
    DIR=$(dirname "$FILE")
    if [[ "$DIR" != "." ]]; then
        echo "mkdir \"$DIR\"" >> "$SCRIPT_FILE"
    fi
    echo "put \"$FILE\" \"$FILE\"" >> "$SCRIPT_FILE"
done

echo "exit" >> "$SCRIPT_FILE"

echo ""
echo "Executing transfer..."
echo ""

# Execute WinSCP
if "$WINSCP" /log="$LOG_FILE" /script="$SCRIPT_FILE"; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "SUCCESS: Deployed $# file(s) to $CONNECTION"
    echo "═══════════════════════════════════════════════════════════════"
    RESULT=0
else
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "ERROR: Deployment failed"
    echo "═══════════════════════════════════════════════════════════════"
    echo "Log file: $LOG_FILE"
    cat "$LOG_FILE" 2>/dev/null | tail -20
    RESULT=1
fi

# Cleanup script (keep log on error)
rm -f "$SCRIPT_FILE"
[[ $RESULT -eq 0 ]] && rm -f "$LOG_FILE"

exit $RESULT
