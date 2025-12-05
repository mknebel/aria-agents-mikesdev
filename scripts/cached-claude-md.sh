#!/bin/bash
# cached-claude-md.sh - Cache CLAUDE.md files (global + project)
# Returns combined CLAUDE.md content, cached until mtime changes
# Saves 1-3K tokens per session

CACHE_ROOT="$HOME/.claude/cache/context"
mkdir -p "$CACHE_ROOT"

GLOBAL_MD="$HOME/.claude/CLAUDE.md"
LOCAL_MD="./CLAUDE.md"
CACHE_FILE="$CACHE_ROOT/combined-claude-md"

# Build cache key from mtimes
GLOBAL_MTIME=$(stat -c %Y "$GLOBAL_MD" 2>/dev/null || echo "0")
LOCAL_MTIME=$(stat -c %Y "$LOCAL_MD" 2>/dev/null || echo "0")
CACHE_KEY="${GLOBAL_MTIME}:${LOCAL_MTIME}:$(pwd)"
CACHE_KEY_HASH=$(echo "$CACHE_KEY" | md5sum | cut -d' ' -f1)

CACHE_PATH="$CACHE_FILE-$CACHE_KEY_HASH"

if [ -f "$CACHE_PATH" ]; then
    echo "[CACHED CLAUDE.md]" >&2
    cat "$CACHE_PATH"
else
    # Combine and cache
    {
        echo "# Global Rules"
        cat "$GLOBAL_MD" 2>/dev/null
        if [ -f "$LOCAL_MD" ]; then
            echo ""
            echo "# Project Rules"
            cat "$LOCAL_MD"
        fi
    } | tee "$CACHE_PATH"
    echo "[FRESH CLAUDE.md]" >&2
fi
