---
description: Quick command menu
allowed-tools: Bash
---

Show available quick commands.

```bash
echo "=== Quick Commands ==="
echo ""
echo "  /cost-report     - View today's token usage and estimated cost"
echo "  /index-project   - Build search index for current project"
echo "  /summarize       - Create session summary for context handoff"
echo ""
echo "=== Status ==="

# Show current project index status
PROJECT_ROOT="$(pwd)"
INDEX_NAME=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//')
INDEX_FILE="$HOME/.claude/project-indexes/${INDEX_NAME}.json"

if [[ -f "$INDEX_FILE" ]]; then
    AGE=$(( ($(date +%s) - $(stat -c %Y "$INDEX_FILE")) / 60 ))
    COUNT=$(jq '.file_count' "$INDEX_FILE" 2>/dev/null)
    echo "  Project index: ✓ ${COUNT} files (${AGE}m ago)"
else
    echo "  Project index: ✗ Not built (run /index-project)"
fi

# Show today's usage if available
LOG_FILE="$HOME/.claude/logs/token-usage/$(date +%Y-%m-%d).jsonl"
if [[ -f "$LOG_FILE" ]]; then
    CALLS=$(jq -s 'length' "$LOG_FILE" 2>/dev/null)
    echo "  Today's calls: $CALLS"
fi
```
