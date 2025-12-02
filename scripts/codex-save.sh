#!/bin/bash
# Codex wrapper with automatic variable store
# Usage: codex-save.sh "prompt"
# Output saved to /tmp/claude_vars/codex_last

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

RESULT=$(codex "$@" 2>&1)
echo "$RESULT" > "$VAR_DIR/codex_last"
echo "$RESULT"
echo "📁 Saved to \$codex_last" >&2
