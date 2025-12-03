#!/bin/bash
# Enforce fast mode routing - intercepts Read/Grep/Task and suggests cheaper alternatives
# Returns warning message that Claude will see before executing the tool

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null)

# Check mode
MODE=$(cat ~/.claude/routing-mode 2>/dev/null || echo "fast")
[[ "$MODE" != "fast" ]] && exit 0

# Extract relevant info
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null)
PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // ""' 2>/dev/null)

case "$TOOL_NAME" in
    Read)
        # Check file size
        if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
            LINES=$(wc -l < "$FILE_PATH" 2>/dev/null || true)
            [[ -z "$LINES" ]] && LINES=0
            if [[ "$LINES" -gt 100 ]]; then
                cat << EOF
<pre-tool-use-hook>
⚠️ FAST MODE: Large file ($LINES lines)

Instead of reading the full file, use:
  smart-read.sh "$FILE_PATH" "what you're looking for"

This uses Gemini to extract just what you need (~90% token savings).
</pre-tool-use-hook>
EOF
            fi
        fi
        ;;

    Grep)
        # Warn on exploratory searches
        cat << EOF
<pre-tool-use-hook>
💡 FAST MODE TIP: For exploratory searches, consider:
  smart-search.sh "$PATTERN" or gemini "find $PATTERN" @src

Grep is fine for targeted lookups. Use external tools for exploration.
</pre-tool-use-hook>
EOF
        ;;

    Task)
        SUBAGENT=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // ""' 2>/dev/null)
        if [[ "$SUBAGENT" == "Explore" || "$SUBAGENT" == "general-purpose" ]]; then
            cat << EOF
<pre-tool-use-hook>
⛔ FAST MODE: Claude agent requested ($SUBAGENT)

Use external tools instead:
  gemini "your question" @src/**/*.php
  codex "implement feature"
  smart-search.sh "pattern"

Claude agents should only be used in aria mode (/mode aria).
</pre-tool-use-hook>
EOF
        fi
        ;;
esac

exit 0
