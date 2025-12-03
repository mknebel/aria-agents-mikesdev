#!/bin/bash
# Auto-Index - Background indexing for project
#
# Called on session start to ensure index is fresh
# Runs in background, doesn't block startup
#
# Usage:
#   auto-index.sh /path/to/project &  # Run in background

PROJECT_ROOT="${1:-$(pwd)}"
PROJECT_ROOT=$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)

LOG_FILE="/tmp/claude_vars/auto-index.log"
LOCK_FILE="/tmp/claude_vars/auto-index-$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1).lock"

mkdir -p /tmp/claude_vars

# Prevent multiple instances for same project
if [[ -f "$LOCK_FILE" ]]; then
    pid=$(cat "$LOCK_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "Auto-index already running (PID $pid)" >> "$LOG_FILE"
        exit 0
    fi
fi

echo $$ > "$LOCK_FILE"
trap "rm -f '$LOCK_FILE'" EXIT

echo "$(date): Auto-index started for $PROJECT_ROOT" >> "$LOG_FILE"

# Find or create index
INDEX_NAME=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
INDEX_DIR="$HOME/.claude/indexes/$INDEX_NAME"
MASTER_INDEX="$INDEX_DIR/master.json"

# Check if index exists and is fresh (< 1 hour old)
if [[ -f "$MASTER_INDEX" ]]; then
    INDEX_AGE=$(( $(date +%s) - $(stat -c %Y "$MASTER_INDEX" 2>/dev/null || echo 0) ))
    if [[ $INDEX_AGE -lt 3600 ]]; then
        echo "$(date): Index is fresh ($((INDEX_AGE / 60)) min old), skipping" >> "$LOG_FILE"
        exit 0
    fi
fi

# Run incremental index (won't rebuild if no changes)
echo "$(date): Running incremental index..." >> "$LOG_FILE"
"$HOME/.claude/scripts/index-v2/build-index.sh" "$PROJECT_ROOT" >> "$LOG_FILE" 2>&1

echo "$(date): Auto-index complete" >> "$LOG_FILE"
