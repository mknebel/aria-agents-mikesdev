---
description: Show search cache status and statistics
allowed-tools: Bash
---

Show search cache statistics:

```bash
/home/mike/.claude/scripts/search-cache.sh stats

echo ""
echo "=== Cache Debug Log (last 10 entries) ==="
tail -10 /tmp/cache-debug.log 2>/dev/null || echo "No cache activity logged"
```
