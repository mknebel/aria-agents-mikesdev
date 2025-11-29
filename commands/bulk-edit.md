---
description: Efficient multi-file or multi-location edits
allowed-tools: MultiEdit, Edit, Grep
---

Bulk edit request: $ARGUMENTS

1. First, search to find all locations (ONE Grep call, files_with_matches)
2. For same-file changes: Use MultiEdit (one call per file)
3. For multi-file changes: Parallel Edit calls in ONE message
4. NEVER do sequential Edit calls when parallel is possible
