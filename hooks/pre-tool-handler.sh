#!/bin/bash
# pre-tool-handler.sh - Consolidated PreToolUse hook
# Combines: fast-mode-tool, enforce-grep-context, limit-large-reads,
#           search-cache-check, file-cache, use-project-index, compress-prompt

INPUT=$(cat 2>/dev/null) || exit 0

# Ensure jq is available
command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null) || true

# Exit silently if no tool name
if [ -z "$TOOL_NAME" ]; then
    exit 0
fi

CACHE_DIR="/tmp/claude_tool_cache"
mkdir -p "$CACHE_DIR" 2>/dev/null

# ─────────────────────────────────────────────
# 1. FAST MODE - Suggest external tools
# ─────────────────────────────────────────────
MODE_FILE="$HOME/.claude/routing-mode"
if [ -f "$MODE_FILE" ] && [ "$(cat "$MODE_FILE" 2>/dev/null)" = "fast" ]; then
    case "$TOOL_NAME" in
        Grep|Read|Task)
            cat << 'EOF'
<pre-tool-use-hook>
⚡ Fast mode: Consider ctx "query" for searches
</pre-tool-use-hook>
EOF
            ;;
    esac
fi

# ─────────────────────────────────────────────
# 2. GREP - Enforce context, check cache
# ─────────────────────────────────────────────
if [ "$TOOL_NAME" = "Grep" ]; then
    PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // empty' 2>/dev/null) || true

    # Check cache
    if [ -n "$PATTERN" ]; then
        CACHE_KEY=$(echo "$PATTERN" | md5sum | cut -d' ' -f1)
        CACHE_FILE="$CACHE_DIR/grep_${CACHE_KEY}.txt"

        if [ -f "$CACHE_FILE" ]; then
            AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
            if [ "$AGE" -lt 300 ]; then
                echo "<!-- Cache hit: grep $PATTERN (${AGE}s old) -->"
            fi
        fi
    fi
fi

# ─────────────────────────────────────────────
# 3. READ - Limit large files, check cache
# ─────────────────────────────────────────────
if [ "$TOOL_NAME" = "Read" ]; then
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null) || true

    if [ -f "$FILE_PATH" ]; then
        SIZE=$(stat -c %s "$FILE_PATH" 2>/dev/null || echo 0)
        LINES=$(wc -l < "$FILE_PATH" 2>/dev/null || echo 0)

        # Warn for large files
        if [ "$LINES" -gt 500 ]; then
            cat << EOF
<pre-tool-use-hook>
⚠️ Large file: $LINES lines. Consider using limit parameter.
</pre-tool-use-hook>
EOF
        fi

        # Check file cache
        CACHE_KEY=$(echo "$FILE_PATH" | md5sum | cut -d' ' -f1)
        CACHE_FILE="$CACHE_DIR/read_${CACHE_KEY}.meta"
        FILE_MTIME=$(stat -c %Y "$FILE_PATH" 2>/dev/null || echo 0)

        if [ -f "$CACHE_FILE" ]; then
            CACHED_MTIME=$(cat "$CACHE_FILE" 2>/dev/null || echo 0)
            if [ "$FILE_MTIME" = "$CACHED_MTIME" ]; then
                echo "<!-- File unchanged since last read -->"
            fi
        fi
    fi
fi

exit 0
