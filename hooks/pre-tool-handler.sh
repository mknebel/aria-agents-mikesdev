#!/bin/bash
# Pre-tool hook - Enforces external-first workflow
# ARIA mode with integrated external-first (no mode toggle needed)

INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL" ] && exit 0

STATE_FILE="$HOME/.claude/.session-state"
[ ! -f "$STATE_FILE" ] && echo '{"ctx_used":false,"files_read":0,"gen_count":0}' > "$STATE_FILE"

CTX_USED=$(jq -r '.ctx_used // false' "$STATE_FILE" 2>/dev/null)
FILES_READ=$(jq -r '.files_read // 0' "$STATE_FILE" 2>/dev/null)
GEN_COUNT=$(jq -r '.gen_count // 0' "$STATE_FILE" 2>/dev/null)

# ARIA icon (external-first is integrated)
ICON="🎭"

# Status output function - Claude sees this
status_msg() {
    echo "{\"status\":\"$1\",\"icon\":\"$ICON\"}"
}

case "$TOOL" in
    Grep)
        if [ "$CTX_USED" = "false" ]; then
            status_msg "⚠️ Grep before ctx! Use: ctx query first"
        fi
        ;;
    Read)
        FILES_READ=$((FILES_READ + 1))
        jq ".files_read = $FILES_READ" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        if [ "$FILES_READ" -gt 3 ] && [ "$CTX_USED" = "false" ]; then
            status_msg "⚠️ $FILES_READ reads without ctx. Consider: ctx query"
        fi
        ;;
    Task)
        AGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
        if [ "$AGENT" = "Explore" ]; then
            jq '.ctx_used = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        fi
        status_msg "$ICON $AGENT agent"
        ;;
    Bash)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        if [[ "$CMD" == *"ctx "* ]] || [[ "$CMD" == *"gemini "* ]]; then
            jq '.ctx_used = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            status_msg "✓ External context"
        elif [[ "$CMD" == *"codex"* ]] || [[ "$CMD" == *"llm "* ]]; then
            GEN_COUNT=$((GEN_COUNT + 1))
            jq ".gen_count = $GEN_COUNT" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            status_msg "✓ External generation"
        elif [[ "$CMD" == *"plan-pipeline"* ]]; then
            status_msg "⚡ Pipeline started"
        elif [[ "$CMD" == *"quality-gate"* ]]; then
            status_msg "🔍 Quality gate"
        fi
        ;;
esac

exit 0
