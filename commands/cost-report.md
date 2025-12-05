---
description: Show token usage and cost estimate
---

```bash
LOG="$HOME/.claude/logs/token-usage/$(date +%Y-%m-%d).jsonl"
[[ ! -f "$LOG" ]] && { echo "No usage data today."; exit 0; }

echo "=== Today's Usage ==="
jq -s 'group_by(.tool)|map({t:.[0].tool,c:length})|sort_by(.c)|reverse|.[]|"\(.t): \(.c)"' "$LOG" 2>/dev/null

CALLS=$(jq -s 'length' "$LOG")
IN=$(jq -s 'map(.input_chars)|add' "$LOG")
OUT=$(jq -s 'map(.output_chars)|add' "$LOG")
echo -e "\nTotal: $CALLS calls, ~$((IN/4)) in tokens, ~$((OUT/4)) out tokens"
```
