---
description: View or update project tasks
allowed-tools: Bash, Read, Edit, Grep
---

Manage tasks in the project's TASKS.md file.

Usage:
- `/task` - Show open tasks
- `/task done <description>` - Mark a task complete
- `/task add <description>` - Add new task

First, find the tasks file:
```bash
for f in TASKS.md tasks.md TODO.md todo.md .tasks.md; do
    if [[ -f "$f" ]]; then
        echo "Found: $f"
        exit 0
    fi
done
echo "No tasks file found. Create TASKS.md? (I'll help)"
```

Then:
1. If showing tasks: Display open/pending items in a table
2. If marking done: Update the task status and add completion date
3. If adding: Append new task with today's date

Keep the format consistent with existing file structure.
