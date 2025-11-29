---
description: Show token usage and estimated cost for today
allowed-tools: Bash
---

Analyze today's token usage and estimate cost:

```bash
LOG_DIR="$HOME/.claude/logs/token-usage"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).jsonl"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "No usage data for today yet."
    echo "Token tracking is active - data will appear after tool calls."
    exit 0
fi

echo "=== Today's Tool Usage ==="
echo ""

# Group by tool
jq -s 'group_by(.tool) | map({
    tool: .[0].tool,
    calls: length,
    input_chars: (map(.input_chars) | add),
    output_chars: (map(.output_chars) | add)
}) | sort_by(.calls) | reverse' "$LOG_FILE" 2>/dev/null | jq -r '.[] | "\(.tool): \(.calls) calls, \(.input_chars) in, \(.output_chars) out"'

echo ""
echo "=== Totals ==="

TOTAL_CALLS=$(jq -s 'length' "$LOG_FILE" 2>/dev/null)
TOTAL_IN=$(jq -s 'map(.input_chars) | add' "$LOG_FILE" 2>/dev/null)
TOTAL_OUT=$(jq -s 'map(.output_chars) | add' "$LOG_FILE" 2>/dev/null)

# Estimate tokens (rough: 4 chars per token)
TOKENS_IN=$((TOTAL_IN / 4))
TOKENS_OUT=$((TOTAL_OUT / 4))

echo "Total tool calls: $TOTAL_CALLS"
echo "Total input: $TOTAL_IN chars (~$TOKENS_IN tokens)"
echo "Total output: $TOTAL_OUT chars (~$TOKENS_OUT tokens)"

# Cost estimation (Opus pricing: $15/1M input, $75/1M output)
# Using bc for floating point
if command -v bc &> /dev/null; then
    COST_IN=$(echo "scale=6; $TOKENS_IN * 0.000015" | bc)
    COST_OUT=$(echo "scale=6; $TOKENS_OUT * 0.000075" | bc)
    COST_TOTAL=$(echo "scale=4; $COST_IN + $COST_OUT" | bc)
    echo ""
    echo "=== Estimated Cost (Opus pricing) ==="
    echo "Input cost:  \$$COST_IN"
    echo "Output cost: \$$COST_OUT"
    echo "Total:       \$$COST_TOTAL"
else
    echo ""
    echo "(Install bc for cost estimation)"
fi

echo ""
echo "=== By Session ==="
jq -s 'group_by(.session) | map({session: .[0].session, calls: length}) | sort_by(.calls) | reverse | .[0:5]' "$LOG_FILE" 2>/dev/null | jq -r '.[] | "  \(.session): \(.calls) calls"'
```
