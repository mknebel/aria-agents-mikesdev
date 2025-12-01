#!/bin/bash
# MiniMax M2 - Best for agentic tasks, modifications, test generation
# 46.3% Terminal-Bench (best), 69.4% SWE-bench
set -euo pipefail

PROMPT=${1:-""}
MAX_TOKENS=${2:-8000}

if [[ -z "$PROMPT" ]]; then
  echo "Usage: call-minimax.sh <prompt> [max_tokens]" >&2
  exit 1
fi

exec /home/mike/.claude/scripts/call-openrouter.sh "minimax/minimax-m2" "$PROMPT" "$MAX_TOKENS"
