#!/bin/bash
# PostToolUse hook - Suggests context summary when token usage is high
# Checks cumulative output size and suggests /summarize if getting large

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Get today's log
LOG_FILE="$HOME/.claude/logs/token-usage/$(date +%Y-%m-%d).jsonl"

if [[ ! -f "$LOG_FILE" ]]; then
    exit 0
fi

# Calculate session's total output chars
SESSION_SHORT="${SESSION_ID:0:8}"
TOTAL_OUTPUT=$(grep "\"session\":\"$SESSION_SHORT\"" "$LOG_FILE" 2>/dev/null | jq -s 'map(.output_chars) | add // 0')

# If over 500KB of output, suggest summary (roughly 125K tokens)
if [[ "$TOTAL_OUTPUT" -gt 500000 ]]; then
    MARKER_FILE="/tmp/summary-suggested-$SESSION_SHORT"
    if [[ ! -f "$MARKER_FILE" ]]; then
        echo "$(date): Session $SESSION_SHORT has $TOTAL_OUTPUT chars output - suggesting summary" >> /tmp/summary-debug.log
        touch "$MARKER_FILE"
        # Output suggestion (will appear in hook output)
        echo "NOTE: Session context is getting large (~$((TOTAL_OUTPUT / 4000))K tokens). Consider running /summarize to compact."
    fi
fi

exit 0
