#!/bin/bash
# post-tool-handler.sh - Consolidated PostToolUse hook
# Combines: var-store, track-usage, short-response, search-cache-store, log-file-changes

# Read input, fail silently on any error
INPUT=$(cat 2>/dev/null) || exit 0

# Ensure jq is available
command -v jq >/dev/null 2>&1 || exit 0

# Parse JSON - fail silently if malformed
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

# Exit silently if no tool name (POSIX syntax)
if [ -z "$TOOL_NAME" ]; then
    exit 0
fi

TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null) || true
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_response // .tool_output // empty' 2>/dev/null) || true

VAR_DIR="/tmp/claude_vars"
CACHE_DIR="/tmp/claude_tool_cache"
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$VAR_DIR" "$CACHE_DIR" "$LOG_DIR" 2>/dev/null

# ─────────────────────────────────────────────
# 1. VARIABLE STORE (auto-save tool outputs)
# ─────────────────────────────────────────────
VAR_NAME=""
case "$TOOL_NAME" in
    Grep)
        VAR_NAME="grep_last"
        ;;
    Read)
        VAR_NAME="read_last"
        ;;
esac

if [ -n "$VAR_NAME" ] && [ -n "$TOOL_OUTPUT" ]; then
    # Only save if output is substantial
    OUTPUT_LEN=${#TOOL_OUTPUT}
    if [ "$OUTPUT_LEN" -gt 50 ] && [ "$OUTPUT_LEN" -lt 100000 ]; then
        echo "$TOOL_OUTPUT" > "$VAR_DIR/${VAR_NAME}.txt" 2>/dev/null
        echo "$(date +%s)|$OUTPUT_LEN|$(echo "$TOOL_OUTPUT" | wc -l)|$TOOL_NAME" > "$VAR_DIR/${VAR_NAME}.meta" 2>/dev/null
    fi
fi

# ─────────────────────────────────────────────
# 2. GREP CACHE STORE
# ─────────────────────────────────────────────
if [ "$TOOL_NAME" = "Grep" ]; then
    PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // empty' 2>/dev/null) || true
    if [ -n "$PATTERN" ] && [ -n "$TOOL_OUTPUT" ]; then
        CACHE_KEY=$(echo "$PATTERN" | md5sum | cut -d' ' -f1)
        echo "$TOOL_OUTPUT" > "$CACHE_DIR/grep_${CACHE_KEY}.txt" 2>/dev/null
    fi
fi

# ─────────────────────────────────────────────
# 3. READ CACHE STORE (mtime)
# ─────────────────────────────────────────────
if [ "$TOOL_NAME" = "Read" ]; then
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null) || true
    if [ -f "$FILE_PATH" ]; then
        CACHE_KEY=$(echo "$FILE_PATH" | md5sum | cut -d' ' -f1)
        stat -c %Y "$FILE_PATH" > "$CACHE_DIR/read_${CACHE_KEY}.meta" 2>/dev/null
    fi
fi

# ─────────────────────────────────────────────
# 4. LOG FILE CHANGES
# ─────────────────────────────────────────────
case "$TOOL_NAME" in
    Edit|Write|MultiEdit)
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null) || true
        if [ -n "$FILE_PATH" ]; then
            echo "$(date -Iseconds) $TOOL_NAME $FILE_PATH" >> "$LOG_DIR/file-changes.log" 2>/dev/null
        fi
        ;;
esac

# ─────────────────────────────────────────────
# 5. TRACK USAGE (lightweight)
# ─────────────────────────────────────────────
USAGE_FILE="$LOG_DIR/usage-$(date +%Y-%m-%d).log"
echo "$(date +%H:%M:%S) $TOOL_NAME" >> "$USAGE_FILE" 2>/dev/null

exit 0
