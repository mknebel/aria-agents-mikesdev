---
description: Sync ~/.claude config to git (single efficient command)
allowed-tools: Bash
---

Sync the global Claude config to git repository.

Execute as ONE Bash command with && chaining:

```bash
cd ~/.claude && \
git add -A && \
git status --short && \
git diff --cached --stat && \
git commit -m "$ARGUMENTS" && \
git push
```

If $ARGUMENTS is empty, use: "Update Claude config"

Do NOT use multiple Bash calls. Chain everything with &&.
