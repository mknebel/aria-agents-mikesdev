#!/bin/bash
# Pre-tool hook for Fast Mode enforcement
# Tracks tool usage patterns and provides reminders about optimal workflows

MODE=$(cat "$HOME/.claude/routing-mode" 2>/dev/null || echo "fast")
[ "$MODE" != "fast" ] && exit 0

INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL" ] && exit 0

LOG="$HOME/.claude/fast-reminders.log"
STATE_FILE="$HOME/.claude/.session-state"

# Initialize session state if needed
[ ! -f "$STATE_FILE" ] && echo '{"index_used":false,"ctx_used":false,"files_read":0}' > "$STATE_FILE"

# Read current state
INDEX_USED=$(jq -r '.index_used // false' "$STATE_FILE" 2>/dev/null)
CTX_USED=$(jq -r '.ctx_used // false' "$STATE_FILE" 2>/dev/null)
FILES_READ=$(jq -r '.files_read // 0' "$STATE_FILE" 2>/dev/null)

case "$TOOL" in
    Grep)
        if [ "$INDEX_USED" = "false" ] && [ "$CTX_USED" = "false" ]; then
            echo "$(date +%H:%M:%S) ⚠️  Grep BEFORE index! Use: /lookup ClassName OR ctx \"query\" first" >> "$LOG"
        else
            echo "$(date +%H:%M:%S) ✓ Grep (after index/ctx)" >> "$LOG"
        fi
        ;;
    Read)
        FILES_READ=$((FILES_READ + 1))
        jq ".files_read = $FILES_READ" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

        if [ "$FILES_READ" -gt 5 ] && [ "$CTX_USED" = "false" ]; then
            echo "$(date +%H:%M:%S) ⚠️  $FILES_READ files read without ctx! Consider: ctx \"query\"" >> "$LOG"
        else
            echo "$(date +%H:%M:%S) 📖 Read ($FILES_READ files this session)" >> "$LOG"
        fi
        ;;
    Task)
        AGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
        if [ "$AGENT_TYPE" = "Explore" ]; then
            # Mark ctx as used when Explore agent is spawned
            jq '.ctx_used = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            echo "$(date +%H:%M:%S) ✓ Explore agent - good for context gathering" >> "$LOG"
        else
            echo "$(date +%H:%M:%S) 🤖 Task agent: $AGENT_TYPE" >> "$LOG"
        fi
        ;;
    Edit|Write)
        echo "$(date +%H:%M:%S) ✏️  $TOOL - applying changes" >> "$LOG"
        ;;
    Bash)
        # Check if using llm or ctx commands
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        if [[ "$CMD" == *"ctx "* ]]; then
            jq '.ctx_used = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            echo "$(date +%H:%M:%S) ✓ ctx command used" >> "$LOG"
        elif [[ "$CMD" == *"llm "* ]]; then
            echo "$(date +%H:%M:%S) ✓ llm command - external generation" >> "$LOG"
        elif [[ "$CMD" == *"/lookup"* ]] || [[ "$CMD" == *"jq"*"index"* ]]; then
            jq '.index_used = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            echo "$(date +%H:%M:%S) ✓ Project index lookup" >> "$LOG"
        fi
        ;;
    SlashCommand)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        if [[ "$CMD" == *"/lookup"* ]]; then
            jq '.index_used = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            echo "$(date +%H:%M:%S) ✓ /lookup used" >> "$LOG"
        fi
        ;;
esac

# Keep only last 30 lines
tail -30 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
exit 0
