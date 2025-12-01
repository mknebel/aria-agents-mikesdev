#!/bin/bash
# Qwen3 Coder - FREE agentic coding model (480B params, 35B active)
# Good for planning, tool use, bulk generation
set -euo pipefail

PROMPT=${1:-""}
MAX_TOKENS=${2:-8000}

if [[ -z "$PROMPT" ]]; then
  echo "Usage: call-qwen.sh <prompt> [max_tokens]" >&2
  exit 1
fi

exec /home/mike/.claude/scripts/call-openrouter.sh "qwen/qwen3-coder:free" "$PROMPT" "$MAX_TOKENS"
