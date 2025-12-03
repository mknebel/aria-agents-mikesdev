#!/bin/bash
# Shell functions for Claude Code shortcuts (docs in ~/.claude/CLAUDE.md)

# Database (local, fast, exact)
function dbquery { ~/.claude/scripts/dbquery.sh "$@"; }

# Log search (local rg, fast)
LYK_LOGS="/mnt/d/MikesDev/www/LaunchYourKid/LaunchYourKid-Cake4/register/logs"
VERITY_LOGS="/mnt/d/MikesDev/www/Whitlock/Verity/VerityCom/logs"
function lyksearch { rg -i "$1" "$LYK_LOGS"/*.log; }
function veritysearch { rg -i "$1" "$VERITY_LOGS"/*.log; }

# PHP/CakePHP (local, fast)
function cake { /mnt/c/Apache24/php74/php.exe bin/cake.php "$@"; }
function php74 { /mnt/c/Apache24/php74/php.exe "$@"; }
function php81 { /mnt/c/Apache24/php81/php.exe "$@"; }

# Browser (LLM-driven, for complex UI tasks)
function ba { ~/.claude/scripts/browser-agent.sh "$@"; }
function bav { ~/.claude/scripts/browser-agent.sh visible "$@"; }

# Codex with index context
function cctx { ~/.claude/scripts/codex-with-context.sh "$@"; }

# Context builder (auto-saves to $ctx_last)
function ctx { ~/.claude/scripts/ctx.sh "$@"; }

# Variable manager (session variables for LLM chains)
function var { ~/.claude/scripts/var.sh "$@"; }

# Smart LLM dispatcher (handles @var: references)
function llm { ~/.claude/scripts/llm.sh "$@"; }

function recent-changes { ~/.claude/scripts/recent-changes.sh "$@"; }

# Navigation (saves 50+ chars)
function cdlyk { cd /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin; }
function cdverity { cd /mnt/d/MikesDev/www/Whitlock/Verity/VerityCom; }
function cdwww { cd /mnt/d/MikesDev/www; }

# Check if project has git changes since last index
_has_git_changes() {
    local project="$1"
    local index_file="$2"

    [[ ! -d "$project/.git" ]] && return 1
    [[ ! -f "$index_file" ]] && return 0

    local index_time=$(stat -c %Y "$index_file" 2>/dev/null || echo 0)
    local last_commit=$(git -C "$project" log -1 --format=%ct 2>/dev/null || echo 0)

    # Refresh if commits newer than index
    [[ $last_commit -gt $index_time ]] && return 0

    # Check for uncommitted changes
    local changes=$(git -C "$project" status --porcelain 2>/dev/null | wc -l)
    [[ $changes -gt 0 ]] && return 0

    return 1
}

# Session warmup (runs in background, non-blocking)
_claude_warmup() {
    local warmup_lock="/tmp/claude_warmup.lock"
    local warmup_log="/tmp/claude_warmup.log"

    # Skip if already running or ran recently (5 min)
    [[ -f "$warmup_lock" ]] && [[ $(( $(date +%s) - $(stat -c %Y "$warmup_lock" 2>/dev/null || echo 0) )) -lt 300 ]] && return

    touch "$warmup_lock"

    # Common project paths to pre-index
    local projects=(
        "/mnt/d/MikesDev/www/LaunchYourKid/LaunchYourKid-Cake4/register"
        "/mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin"
    )

    for project in "${projects[@]}"; do
        if [[ -d "$project" ]]; then
            local index_name=$(echo "$project" | md5sum | cut -d' ' -f1)
            local index_file="$HOME/.claude/indexes/$index_name/inverted.json"
            local need_refresh=false

            # Check: missing, stale (>1 hour), or git changes
            if [[ ! -f "$index_file" ]]; then
                need_refresh=true
            elif [[ $(( $(date +%s) - $(stat -c %Y "$index_file" 2>/dev/null || echo 0) )) -gt 3600 ]]; then
                need_refresh=true
            elif _has_git_changes "$project" "$index_file"; then
                echo "$(date): Git changes detected in $project" >> "$warmup_log"
                need_refresh=true
            fi

            if $need_refresh; then
                echo "$(date): Warming $project" >> "$warmup_log"
                ~/.claude/scripts/index-v2/build-index.sh "$project" >> "$warmup_log" 2>&1 &
            fi
        fi
    done
}

# Run warmup in background (silent, non-blocking)
(_claude_warmup &) 2>/dev/null

# Exports
export -f dbquery lyksearch veritysearch cake php74 php81 ba bav cctx ctx var llm recent-changes cdlyk cdverity cdwww _has_git_changes _claude_warmup
export LYK_LOGS VERITY_LOGS
alias smart-review='~/.claude/scripts/smart-review.sh'
