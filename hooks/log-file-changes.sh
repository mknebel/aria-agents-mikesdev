#!/bin/bash
# PostToolUse hook - Automatically logs file edits/writes

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only log file modifications
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "MultiEdit" ]]; then
    exit 0
fi

TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Determine log location (project root or cwd)
LOG_DIR="$CWD"
if [[ -d "$CWD/.git" ]]; then
    LOG_DIR="$CWD"
elif [[ -d "$(dirname "$CWD")/.git" ]]; then
    LOG_DIR="$(dirname "$CWD")"
fi

LOG_FILE="$LOG_DIR/WORKLOG.md"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

# Create log file if needed
if [[ ! -f "$LOG_FILE" ]]; then
    echo "# Work Log" > "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

# Add date header if not present
if ! grep -q "## $DATE" "$LOG_FILE" 2>/dev/null; then
    echo "" >> "$LOG_FILE"
    echo "## $DATE" >> "$LOG_FILE"
fi

# Get relative path
REL_PATH="${FILE_PATH#$LOG_DIR/}"

# Log the change
echo "- [$TIME] $TOOL_NAME: \`$REL_PATH\`" >> "$LOG_FILE"

exit 0
