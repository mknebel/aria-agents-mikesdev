---
description: Record work done this session
allowed-tools: Bash, Read, Edit
---

Record what was accomplished in this session.

First, check if a work log exists:
```bash
LOG_FILE="$(pwd)/WORKLOG.md"
if [[ ! -f "$LOG_FILE" ]]; then
    echo "# Work Log" > "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi
echo "Log file: $LOG_FILE"
```

Then ask me what was done and I'll append an entry like:

```markdown
## 2025-11-29

### Session Summary
- Fixed billing address sync issue
- Added validation for payment forms
- Updated unit tests

### Files Changed
- `src/Controller/PaymentsController.php`
- `tests/TestCase/Controller/PaymentsTest.php`

### Next Steps
- Review PR #123
- Deploy to staging
```

Keep entries concise. Append to existing log, don't overwrite.
