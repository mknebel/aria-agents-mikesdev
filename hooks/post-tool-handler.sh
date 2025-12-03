#!/bin/bash
# Variable caching hook - saves Grep/Read outputs to /tmp/claude_vars/

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR" 2>/dev/null

INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ -z "$TOOL" ] && exit 0

case "$TOOL" in
    Grep)
        OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.content // empty' 2>/dev/null)
        [ -n "$OUTPUT" ] && echo "$OUTPUT" > "$VAR_DIR/grep_last.txt"
        ;;
    Read)
        OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.file.content // empty' 2>/dev/null)
        [ -n "$OUTPUT" ] && echo "$OUTPUT" > "$VAR_DIR/read_last.txt"
        ;;
esac

exit 0
