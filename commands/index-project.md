---
description: Build or rebuild project index for fast lookups
allowed-tools: Bash
---

Build a project index for the current directory to enable fast file and function lookups.

```bash
/home/mike/.claude/scripts/build-project-index.sh "$(pwd)"
```

After building, report:
- Number of files indexed
- Categories found (controllers, models, views, etc.)
- Index file location and size
