---
description: Show token usage history for past days
allowed-tools: Bash
---

Show token usage history:

```bash
LOG_DIR="$HOME/.claude/logs/token-usage"

echo "=== Usage History ==="
echo ""

if [[ ! -d "$LOG_DIR" ]] || [[ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]]; then
    echo "No usage history found."
    exit 0
fi

# Show last 7 days
for f in $(ls -t "$LOG_DIR"/*.jsonl 2>/dev/null | head -7); do
    DATE=$(basename "$f" .jsonl)
    CALLS=$(jq -s 'length' "$f" 2>/dev/null)
    TOTAL_IN=$(jq -s 'map(.input_chars) | add' "$f" 2>/dev/null)
    TOTAL_OUT=$(jq -s 'map(.output_chars) | add' "$f" 2>/dev/null)

    TOKENS=$((($TOTAL_IN + $TOTAL_OUT) / 4))

    if command -v bc &> /dev/null; then
        COST=$(echo "scale=4; ($TOTAL_IN/4 * 0.000015) + ($TOTAL_OUT/4 * 0.000075)" | bc)
        echo "$DATE: $CALLS calls, ~$TOKENS tokens, ~\$$COST"
    else
        echo "$DATE: $CALLS calls, ~$TOKENS tokens"
    fi
done

echo ""
echo "=== Total (all time) ==="
TOTAL_CALLS=$(cat "$LOG_DIR"/*.jsonl 2>/dev/null | jq -s 'length')
TOTAL_CHARS=$(cat "$LOG_DIR"/*.jsonl 2>/dev/null | jq -s 'map(.input_chars + .output_chars) | add')
echo "Total calls: $TOTAL_CALLS"
echo "Total chars: $TOTAL_CHARS (~$((TOTAL_CHARS / 4)) tokens)"
```
