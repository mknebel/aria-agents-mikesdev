#!/bin/bash
# Post-tool hook - Caches results and shows completion status

MODE=$(cat "$HOME/.claude/routing-mode" 2>/dev/null || echo "fast")
INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL" ] && exit 0

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

FAST_ICON="⚡"
ARIA_ICON="🎭"
MODE_ICON=$([[ "$MODE" == "fast" ]] && echo "$FAST_ICON" || echo "$ARIA_ICON")

case "$TOOL" in
    Grep)
        RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null)
        if [ -n "$RESULT" ]; then
            echo "$RESULT" > "$VAR_DIR/grep_last"
            echo "$MODE_ICON Grep → \$grep_last" >&2
        fi
        ;;
    Read)
        FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null)
        if [ -n "$RESULT" ]; then
            echo "$RESULT" > "$VAR_DIR/read_last.txt"
            # Cache for future reads
            MTIME=$(stat -c %Y "$FILE" 2>/dev/null || echo "0")
            CACHE_KEY=$(echo "${FILE}:${MTIME}" | md5sum | cut -d' ' -f1)
            mkdir -p "$HOME/.claude/cache/context/files"
            echo "$RESULT" > "$HOME/.claude/cache/context/files/$CACHE_KEY"
            echo "$MODE_ICON Read → \$read_last" >&2
        fi
        ;;
    Bash)
        RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        if [[ "$CMD" == *"ctx "* ]] && [ -n "$RESULT" ]; then
            echo "$RESULT" > "$VAR_DIR/ctx_last"
            echo "$MODE_ICON ctx → \$ctx_last" >&2
        elif [[ "$CMD" == *"codex"* ]] && [ -n "$RESULT" ]; then
            echo "$RESULT" > "$VAR_DIR/codex_last"
            echo "$MODE_ICON codex → \$codex_last" >&2
        elif [[ "$CMD" == *"gemini"* ]] && [ -n "$RESULT" ]; then
            echo "$RESULT" > "$VAR_DIR/gemini_last"
            echo "$MODE_ICON gemini → \$gemini_last" >&2
        fi
        ;;
esac

exit 0
