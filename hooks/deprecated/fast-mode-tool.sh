#!/bin/bash
# Consolidated: PreToolUse hook for fast mode warnings
# Replaces: enforce-fast-mode-routing.sh, tool-routing-check.sh

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null)

MODE=$(cat ~/.claude/routing-mode 2>/dev/null || echo "fast")
[[ "$MODE" != "fast" ]] && exit 0

FILE=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null)
PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // ""' 2>/dev/null)

case "$TOOL" in
    Read)
        [[ -n "$FILE" && -f "$FILE" ]] || exit 0
        LINES=$(wc -l < "$FILE" 2>/dev/null || echo 0)
        [[ $LINES -gt 100 ]] && cat << EOF
<pre-tool-use-hook>
⚠️ Large file ($LINES lines). Use: smart-read.sh "$FILE" "question"
</pre-tool-use-hook>
EOF
        ;;
    Grep)
        cat << EOF
<pre-tool-use-hook>
💡 Use indexed search: smart-search.sh "$PATTERN" or ctx "$PATTERN"
</pre-tool-use-hook>
EOF
        ;;
    Task)
        AGENT=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // ""' 2>/dev/null)
        [[ "$AGENT" =~ ^(Explore|general-purpose)$ ]] && cat << EOF
<pre-tool-use-hook>
⛔ Claude agent in fast mode. Use: gemini "query" @files or ctx "query"
</pre-tool-use-hook>
EOF
        ;;
esac
exit 0
