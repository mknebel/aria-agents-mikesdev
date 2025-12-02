#!/bin/bash
# Claude Code shortcuts - source this in ~/.bashrc
# Usage: source ~/.claude/scripts/shortcuts.sh

# =============================================================================
# DATABASE SHORTCUTS (powered by dbquery.sh)
# =============================================================================

# Main dbquery function - use this for most database operations
dbquery() { ~/.claude/scripts/dbquery.sh "$@"; }

# Backward-compatible aliases (now use dbquery under the hood)
lykdb() { dbquery lyk "$@"; }
veritydb() { dbquery verity "$@"; }
mydb() { mysql -h 127.0.0.1 -u root -pmike "$@"; }

# Quick aliases
alias dbl='dbquery --list'
alias dbt='dbquery --test'

# =============================================================================
# LOG SHORTCUTS (use rg for speed)
# =============================================================================

LYK_LOGS="/mnt/d/MikesDev/www/LaunchYourKid/LaunchYourKid-Cake4/register/logs"
VERITY_LOGS="/mnt/d/MikesDev/www/Whitlock/Verity/VerityCom/logs"

# LaunchYourKid logs
lykerr() { tail -${1:-30} "$LYK_LOGS/error.log"; }
lyklog() { tail -${1:-30} "$LYK_LOGS/debug.log"; }
lykwatch() { tail -f "$LYK_LOGS/debug.log"; }
lyksearch() { rg -i "$1" "$LYK_LOGS"/*.log; }

# VerityCom logs
verityerr() { tail -${1:-30} "$VERITY_LOGS/error.log"; }
veritylog() { tail -${1:-30} "$VERITY_LOGS/debug.log"; }
veritysearch() { rg -i "$1" "$VERITY_LOGS"/*.log; }

# =============================================================================
# TEST SHORTCUTS
# =============================================================================

lyktest() {
    cd /mnt/d/MikesDev/www/LaunchYourKid && \
    node LaunchYourKid-Cake4/register/tests/browser/test_singlepayment.js
}

# Run test and show new log entries
testwatch() {
    local cmd="$1"
    local logfile="$2"
    if [ -z "$logfile" ]; then
        eval "$cmd"
    else
        local before=$(wc -l < "$logfile" 2>/dev/null || echo 0)
        eval "$cmd"
        local after=$(wc -l < "$logfile" 2>/dev/null || echo 0)
        local newlines=$((after - before))
        if [ $newlines -gt 0 ]; then
            echo -e "\n--- New log entries ---"
            tail -$newlines "$logfile"
        fi
    fi
}

# =============================================================================
# API TESTING
# =============================================================================

authnet-test() {
    local login="$1"
    local key="$2"
    local env="${3:-sandbox}"

    local url="https://apitest.authorize.net/xml/v1/request.api"
    [ "$env" = "production" ] && url="https://api.authorize.net/xml/v1/request.api"

    curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"authenticateTestRequest\":{\"merchantAuthentication\":{\"name\":\"$login\",\"transactionKey\":\"$key\"}}}" | jq -r '.messages.resultCode // .messages.message[0].text'
}

# =============================================================================
# PHP / CAKEPHP
# =============================================================================

cake() { /mnt/c/Apache24/php74/php.exe bin/cake.php "$@"; }
php74() { /mnt/c/Apache24/php74/php.exe "$@"; }

# =============================================================================
# BROWSER AUTOMATION
# =============================================================================

ba() { ~/.claude/scripts/browser-agent.sh "$@"; }
bav() { ~/.claude/scripts/browser-agent.sh visible "$@"; }

# Export functions for subshells
export -f dbquery mydb lykdb veritydb lykerr lyklog lykwatch lyksearch
export -f verityerr veritylog veritysearch lyktest testwatch authnet-test
export -f cake php74 ba bav
export LYK_LOGS VERITY_LOGS

echo "✓ Claude shortcuts loaded"
