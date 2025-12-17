#!/bin/bash
# Safe loader for shortcuts - silently fails if there's an issue

# WSL fix: some environments mount /run/user/<uid> with root ownership, which breaks tools
# that rely on XDG_RUNTIME_DIR (e.g. `just`). Fall back to /tmp when not writable.
if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -w "${XDG_RUNTIME_DIR:-/nonexistent}" ]; then
  export XDG_RUNTIME_DIR="/tmp"
fi

source ~/.claude/scripts/shortcuts.sh 2>/dev/null || true
