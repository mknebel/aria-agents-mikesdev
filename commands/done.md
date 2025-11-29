---
description: Quick log of completed work
allowed-tools: Bash, Edit
---

Quick command to log completed work. Usage: `/done <what you finished>`

```bash
LOG_FILE="$(pwd)/WORKLOG.md"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

if [[ ! -f "$LOG_FILE" ]]; then
    echo "# Work Log" > "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

# Check if today's section exists
if ! grep -q "## $DATE" "$LOG_FILE" 2>/dev/null; then
    echo "" >> "$LOG_FILE"
    echo "## $DATE" >> "$LOG_FILE"
fi

echo "Logging to: $LOG_FILE"
```

After running the bash, append the work item:
```markdown
- [TIME] <what was done>
```

Keep it brief - one line per item.
