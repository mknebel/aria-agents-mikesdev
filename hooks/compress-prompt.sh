#!/bin/bash

# PreToolUse Hook: Compress verbose patterns in tool inputs
# Logs compression for analysis without blocking tool execution
# Exit 0 to allow tool to proceed

LOG_FILE="/tmp/claude_compression.log"

# Pattern mappings: array of search/replace pairs
declare -a PATTERNS=(
    "Please read the file at "
    ""
    "I need you to "
    ""
    "Can you help me "
    ""
    "The file is located at "
    ""
    "I want you to "
    ""
    "Could you please "
    ""
)

# Read JSON from stdin
input=$(cat)

# Extract the relevant text field (handle different tool input types)
# Try to get 'prompt', 'command', or other input fields
prompt=$(echo "$input" | jq -r '.prompt // .command // .input // .message // .' 2>/dev/null || echo "$input")

if [ -z "$prompt" ]; then
    # No input to compress, exit cleanly
    exit 0
fi

# Apply compression patterns
compressed="$prompt"
original="$prompt"
patterns_applied=0

# Process patterns array (pairs of search/replace)
i=0
while [ $i -lt ${#PATTERNS[@]} ]; do
    search="${PATTERNS[$i]}"
    replace="${PATTERNS[$((i+1))]}"

    if [[ "$compressed" == *"$search"* ]]; then
        compressed="${compressed//"$search"/"$replace"}"
        ((patterns_applied++))
    fi

    ((i+=2))
done

# Log if any compressions were applied
if [ $patterns_applied -gt 0 ] && [ "$compressed" != "$original" ]; then
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compression applied ($patterns_applied patterns)"
        echo "  Original length: ${#original}"
        echo "  Compressed length: ${#compressed}"
        echo "  Savings: $((${#original} - ${#compressed})) chars"
        echo "  Original: ${original:0:100}..."
        echo "  Compressed: ${compressed:0:100}..."
        echo "---"
    } >> "$LOG_FILE"
fi

# Always exit 0 to allow tool to proceed
# (Claude Code hooks cannot modify tool inputs)
exit 0
