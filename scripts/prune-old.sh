#!/bin/bash
# prune-old.sh - Weekly cleanup of old Claude Code data
# Add to crontab: 0 3 * * 0 ~/.claude/scripts/prune-old.sh

set -e

CLAUDE_DIR="$HOME/.claude"
LOG_FILE="$CLAUDE_DIR/logs/prune.log"
DRY_RUN="${1:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M')] $1" | tee -a "$LOG_FILE"; }

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    log "DRY RUN - no files will be deleted"
fi

delete_files() {
    local pattern="$1"
    local desc="$2"
    local count=$(find $pattern 2>/dev/null | wc -l)
    local size=$(du -sh $(find $pattern 2>/dev/null | head -1 | xargs dirname) 2>/dev/null | cut -f1 || echo "0")

    if [[ $count -gt 0 ]]; then
        if [[ "$DRY_RUN" != "--dry-run" ]]; then
            find $pattern -delete 2>/dev/null
        fi
        log "$desc: $count files (~$size)"
    fi
}

log "=== Prune started ==="

# 1. Session logs >7 days
count=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" -mtime +7 2>/dev/null | wc -l)
if [[ $count -gt 0 ]]; then
    [[ "$DRY_RUN" != "--dry-run" ]] && find "$CLAUDE_DIR/projects" -name "*.jsonl" -mtime +7 -delete 2>/dev/null
    log "Session logs >7d: $count files"
fi

# 2. Debug logs >3 days
count=$(find "$CLAUDE_DIR/debug" -type f -mtime +3 2>/dev/null | wc -l)
if [[ $count -gt 0 ]]; then
    [[ "$DRY_RUN" != "--dry-run" ]] && find "$CLAUDE_DIR/debug" -type f -mtime +3 -delete 2>/dev/null
    log "Debug logs >3d: $count files"
fi

# 3. Browser screenshots >1 day
count=$(find "$CLAUDE_DIR/browser-screenshots" -type f -mtime +1 2>/dev/null | wc -l)
if [[ $count -gt 0 ]]; then
    [[ "$DRY_RUN" != "--dry-run" ]] && find "$CLAUDE_DIR/browser-screenshots" -type f -mtime +1 -delete 2>/dev/null
    log "Screenshots >1d: $count files"
fi

# 4. Cache files >1 day
count=$(find "$CLAUDE_DIR/cache" -type f -mtime +1 2>/dev/null | wc -l)
if [[ $count -gt 0 ]]; then
    [[ "$DRY_RUN" != "--dry-run" ]] && find "$CLAUDE_DIR/cache" -type f -mtime +1 -delete 2>/dev/null
    log "Cache >1d: $count files"
fi

# 5. Empty directories
[[ "$DRY_RUN" != "--dry-run" ]] && find "$CLAUDE_DIR" -type d -empty -delete 2>/dev/null

# Summary
total=$(du -sh "$CLAUDE_DIR" | cut -f1)
log "=== Done. Total size: $total ==="
