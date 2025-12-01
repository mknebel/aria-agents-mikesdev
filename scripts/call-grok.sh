#!/bin/bash
# Grok Code Fast 1 - Rapid iteration, quick quality code (160 tps)
# 70.8% SWE-bench
set -euo pipefail

PROMPT=${1:-""}
MAX_TOKENS=${2:-8000}

if [[ -z "$PROMPT" ]]; then
  echo "Usage: call-grok.sh <prompt> [max_tokens]" >&2
  exit 1
fi

exec /home/mike/.claude/scripts/call-openrouter.sh "x-ai/grok-code-fast-1" "$PROMPT" "$MAX_TOKENS"
