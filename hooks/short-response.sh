#!/bin/bash
# PostToolUse hook: Output short summaries for large tool results
# Check ~/.claude/response-mode file:
# - If contains "short": output abbreviated summaries
# - If contains "verbose" or missing: exit 0 (no change)

RESPONSE_MODE_FILE="$HOME/.claude/response-mode"

# Check if response mode is set to "short"
if [[ ! -f "$RESPONSE_MODE_FILE" ]] || ! grep -q "short" "$RESPONSE_MODE_FILE"; then
    exit 0
fi

# Read JSON input from stdin
input=$(cat)

# Extract tool name and tool result using jq
tool_name=$(echo "$input" | jq -r '.tool_name // "Unknown"')
tool_result=$(echo "$input" | jq -r '.tool_result // ""')

case "$tool_name" in
    Read)
        # Extract filename from tool_result or use "file"
        filename=$(echo "$input" | jq -r '.tool_params.file_path // "file"' 2>/dev/null || echo "file")
        line_count=$(echo "$tool_result" | wc -l)
        char_count=${#tool_result}
        echo "<short-summary>📄 $(basename "$filename"): $line_count lines, $char_count chars (stored in \$read_last)</short-summary>"
        ;;
    Grep)
        # Count matches
        match_count=$(echo "$tool_result" | grep -c . 2>/dev/null || echo "0")
        echo "<short-summary>🔍 $match_count matches (stored in \$grep_last)</short-summary>"
        ;;
    Edit)
        # Extract filename from parameters
        filename=$(echo "$input" | jq -r '.tool_params.file_path // "file"' 2>/dev/null || echo "file")
        echo "<short-summary>✓ Edited $(basename "$filename")</short-summary>"
        ;;
    Write)
        # Extract filename from parameters
        filename=$(echo "$input" | jq -r '.tool_params.file_path // "file"' 2>/dev/null || echo "file")
        echo "<short-summary>✓ Created $(basename "$filename")</short-summary>"
        ;;
    *)
        exit 0
        ;;
esac
