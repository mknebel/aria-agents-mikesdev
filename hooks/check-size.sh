#!/bin/bash
# check-size.sh - Enforce size limits on Claude config files
# Usage: check-size.sh [--fix]
#
# Limits: Agents 35 lines, Commands 40 lines

AGENT_MAX=35
CMD_MAX=40
ERRORS=0

check_files() {
    local dir="$1"
    local max="$2"
    local type="$3"

    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        lines=$(wc -l < "$f")
        if [ "$lines" -gt "$max" ]; then
            echo "❌ $type $(basename "$f"): $lines lines (max $max)"
            ((ERRORS++))
        fi
    done
}

echo "🔍 Checking size limits..."
check_files ~/.claude/agents "$AGENT_MAX" "Agent"
check_files ~/.claude/commands "$CMD_MAX" "Command"

# Check CLAUDE.md
if [ -f ~/.claude/CLAUDE.md ]; then
    lines=$(wc -l < ~/.claude/CLAUDE.md)
    if [ "$lines" -gt 30 ]; then
        echo "❌ CLAUDE.md: $lines lines (max 30)"
        ((ERRORS++))
    fi
fi

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "❌ $ERRORS file(s) exceed size limits"
    echo "Run: slim-config.sh to auto-compress"
    exit 1
else
    echo "✅ All files within limits"
    exit 0
fi
