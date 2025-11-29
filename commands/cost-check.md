---
description: Estimate session cost and token usage
allowed-tools: Bash
---

Estimate current session efficiency.

Check debug logs and summarize:
```bash
echo "=== Hook Activity ===" && \
wc -l /tmp/hook-debug.log /tmp/auto-route-debug.log 2>/dev/null && \
echo "" && \
echo "=== Recent Grep Hooks ===" && \
tail -5 /tmp/hook-debug.log 2>/dev/null && \
echo "" && \
echo "=== Recent Auto-Routes ===" && \
tail -5 /tmp/auto-route-debug.log 2>/dev/null
```

Provide brief summary:
- How many tool calls were optimized
- Estimated savings vs unoptimized
- Any issues detected
