---
description: Show token usage history
---

```bash
DIR="$HOME/.claude/logs/token-usage"
[[ ! -d "$DIR" ]] && { echo "No history."; exit 0; }

echo "=== Last 7 Days ==="
for f in $(ls -t "$DIR"/*.jsonl 2>/dev/null | head -7); do
    D=$(basename "$f" .jsonl)
    C=$(jq -s 'length' "$f")
    T=$(jq -s 'map(.input_chars+.output_chars)|add//0' "$f")
    echo "$D: $C calls, ~$((T/4)) tokens"
done
```
