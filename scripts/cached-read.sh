#!/bin/bash
# cached-read.sh - Read file with caching (invalidates on mtime change)
# Usage: cached-read.sh <file_path>
# Saves ~50-100ms per cached read, avoids re-sending unchanged content

FILE="$1"
CACHE_ROOT="$HOME/.claude/cache/context/files"
mkdir -p "$CACHE_ROOT"

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE" >&2
    exit 1
fi

# Cache key = path + mtime
MTIME=$(stat -c %Y "$FILE" 2>/dev/null || stat -f %m "$FILE" 2>/dev/null)
CACHE_KEY=$(echo "${FILE}:${MTIME}" | md5sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_ROOT/$CACHE_KEY"

if [ -f "$CACHE_FILE" ]; then
    # Cache hit
    echo "[CACHED] $FILE" >&2
    cat "$CACHE_FILE"
else
    # Cache miss - read and store
    cat "$FILE" | tee "$CACHE_FILE"
    echo "[FRESH] $FILE" >&2
fi
