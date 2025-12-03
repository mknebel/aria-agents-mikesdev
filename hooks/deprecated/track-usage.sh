#!/bin/bash
# PostToolUse hook - Tracks tool usage for cost estimation

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Get tool input and output sizes
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty')

INPUT_CHARS=${#TOOL_INPUT}
OUTPUT_CHARS=${#TOOL_OUTPUT}

# Log to daily file
LOG_DIR="$HOME/.claude/logs/token-usage"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).jsonl"

# Append log entry
echo "{\"ts\":\"$(date -Iseconds)\",\"session\":\"${SESSION_ID:0:8}\",\"tool\":\"$TOOL_NAME\",\"input_chars\":$INPUT_CHARS,\"output_chars\":$OUTPUT_CHARS}" >> "$LOG_FILE"

exit 0
