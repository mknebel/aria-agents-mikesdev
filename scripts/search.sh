#!/usr/bin/env bash
# Simple search wrapper - ripgrep with JSON output
# Usage: search.sh "<pattern>" "<path>"

PATTERN="$1"
ROOT="${2:-.}"

[ -z "$PATTERN" ] && echo "Usage: search.sh \"<pattern>\" [path]" && exit 1

# ripgrep JSON output for machine readability
rg --hidden --glob '!.git' --json "$PATTERN" "$ROOT"
