#!/bin/bash
# Gemini wrapper with automatic variable store
# Usage: gemini-save.sh "prompt" [@files...]
# Output saved to /tmp/claude_vars/gemini_last

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

RESULT=$(gemini "$@" 2>&1)
echo "$RESULT" > "$VAR_DIR/gemini_last"
echo "$RESULT"
echo "📁 Saved to \$gemini_last" >&2
