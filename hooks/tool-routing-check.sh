#!/bin/bash
# Hook: Remind Claude to use external tools in fast mode
# This runs on tool calls and can warn about expensive operations

TOOL_NAME="$1"
MODE=$(cat ~/.claude/routing-mode 2>/dev/null || echo "fast")

# Only check in fast mode
if [[ "$MODE" != "fast" ]]; then
    exit 0
fi

# Warn on expensive tools
case "$TOOL_NAME" in
    Read|Grep|Task)
        echo "⚠️ FAST MODE: Consider using external tools instead:"
        echo "  Read → smart-read.sh file 'question'"
        echo "  Grep → smart-search.sh 'pattern' or gemini"
        echo "  Task → gemini or codex"
        ;;
esac

exit 0
