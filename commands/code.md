---
description: Quick code lookup with context (single efficient search)
allowed-tools: Grep
---

Find code: $ARGUMENTS

Execute ONE Grep call with:
- Combined pattern from keywords
- -C: 10 for context
- head_limit: 100
- output_mode: "content"
- glob: "*.php" (or appropriate for project)

Do NOT follow up with Read calls - context should be sufficient.
