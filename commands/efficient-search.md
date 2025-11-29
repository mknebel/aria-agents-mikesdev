---
description: Fast parallel search using efficient agent (saves tokens)
allowed-tools: Task, Grep
---

Search request: $ARGUMENTS

Use the parallel-work-manager-fast agent to perform this search efficiently:

1. Parse the search request to identify:
   - Patterns to search for
   - Paths to search in
   - File types to filter

2. Execute with parallel-work-manager-fast agent which uses OpenRouter for speed:
   - Combined regex patterns
   - Parallel searches across paths
   - Return summarized results with file:line references

3. Return consolidated findings to main conversation.

Do NOT use sequential Grep calls. The agent handles parallelization.
