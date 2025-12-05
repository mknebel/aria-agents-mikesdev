#!/bin/bash
# cached-structure.sh - Cache project structure tree
# Invalidates when file count changes or every 5 minutes
# Saves 2-5K tokens per session

CACHE_ROOT="$HOME/.claude/cache/context"
mkdir -p "$CACHE_ROOT"

PROJECT_PATH="${1:-.}"
CACHE_FILE="$CACHE_ROOT/structure-$(echo "$PROJECT_PATH" | md5sum | cut -d' ' -f1)"

# Quick file count for invalidation
FILE_COUNT=$(find "$PROJECT_PATH" -type f ! -path '*/node_modules/*' ! -path '*/.git/*' ! -path '*/vendor/*' 2>/dev/null | wc -l)

# Check cache validity (5 min TTL + file count)
if [ -f "$CACHE_FILE" ] && [ -f "$CACHE_FILE.meta" ]; then
    CACHED_COUNT=$(jq -r '.file_count' "$CACHE_FILE.meta" 2>/dev/null)
    CACHED_TIME=$(jq -r '.created' "$CACHE_FILE.meta" 2>/dev/null)
    NOW=$(date +%s)
    AGE=$((NOW - CACHED_TIME))

    if [ "$FILE_COUNT" = "$CACHED_COUNT" ] && [ "$AGE" -lt 300 ]; then
        echo "[CACHED STRUCTURE]" >&2
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Generate fresh structure
STRUCTURE=$(find "$PROJECT_PATH" -type f \
    ! -path '*/node_modules/*' \
    ! -path '*/.git/*' \
    ! -path '*/vendor/*' \
    ! -path '*/.cache/*' \
    ! -name '*.lock' \
    2>/dev/null | head -200 | sort)

echo "$STRUCTURE" > "$CACHE_FILE"
echo "{\"created\":$(date +%s),\"file_count\":$FILE_COUNT}" > "$CACHE_FILE.meta"
echo "[FRESH STRUCTURE]" >&2
cat "$CACHE_FILE"
