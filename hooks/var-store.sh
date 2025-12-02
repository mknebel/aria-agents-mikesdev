#!/bin/bash
# PostToolUse hook - stores tool outputs as variables
# Enables pass-by-reference pattern (82% token savings)

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null)

# Skip if no result or small result
[ -z "$RESULT" ] && exit 0
[ ${#RESULT} -lt 500 ] && exit 0

# Create var directory
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

# Store with tool name
TOOL_LOWER=$(echo "$TOOL" | tr '[:upper:]' '[:lower:]')
echo "$RESULT" > "$VAR_DIR/${TOOL_LOWER}_last"

# Also store with timestamp for history
echo "$RESULT" > "$VAR_DIR/${TOOL_LOWER}_$(date +%s)"

# Output hint to Claude
LINES=$(echo "$RESULT" | wc -l)
CHARS=${#RESULT}

if [ $CHARS -gt 1000 ]; then
    cat << EOF
<tool-output-stored>
Large output (${LINES} lines, ${CHARS} chars) stored as variable.
Reference: \$${TOOL_LOWER}_last
File path: $VAR_DIR/${TOOL_LOWER}_last

To pass this data to another tool, use the variable reference instead of re-outputting.
Example: "Use the data in \$${TOOL_LOWER}_last" or reference the file path.
</tool-output-stored>
EOF
fi

exit 0
