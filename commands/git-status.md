---
description: Quick git status overview
allowed-tools: Bash
---

Show a quick overview of git status.

```bash
echo "=== Branch ==="
git branch --show-current

echo ""
echo "=== Status ==="
git status --short

echo ""
echo "=== Recent Commits ==="
git log --oneline -5

echo ""
echo "=== Remote ==="
git remote -v | head -2
```
