#!/bin/bash
# PreToolUse hook - suggest external tools in fast mode

MODE_FILE="$HOME/.claude/routing-mode"
MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "fast")

# Only act in fast mode
[ "$MODE" != "fast" ] && exit 0

INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ -z "$TOOL" ] && exit 0

case "$TOOL" in
    Grep)
        echo '<pre-tool-use-hook>'
        echo 'Fast mode: Consider ctx "query" or smart-search.sh for exploratory searches'
        echo '</pre-tool-use-hook>'
        ;;
    Read)
        # Check file size if possible
        FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        if [ -n "$FILE" ] && [ -f "$FILE" ]; then
            LINES=$(wc -l < "$FILE" 2>/dev/null || echo 0)
            if [ "$LINES" -gt 100 ]; then
                echo '<pre-tool-use-hook>'
                echo "Fast mode: Large file ($LINES lines). Consider smart-read.sh \"$FILE\" \"question\""
                echo '</pre-tool-use-hook>'
            fi
        fi
        ;;
    Task)
        echo '<pre-tool-use-hook>'
        echo 'Fast mode: Consider ctx or codex for simpler tasks'
        echo '</pre-tool-use-hook>'
        ;;
esac

exit 0
