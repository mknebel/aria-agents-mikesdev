---
description: Sync current branch with remote (pull + push)
allowed-tools: Bash
---

Sync the current branch with its remote tracking branch.

```bash
BRANCH=$(git branch --show-current)

echo "Syncing branch: $BRANCH"
echo ""

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo "Uncommitted changes detected:"
    git status --short
    echo ""
    echo "Options:"
    echo "1. Commit changes first"
    echo "2. Stash changes: git stash"
    echo "3. Discard changes: git checkout -- ."
    exit 1
fi

# Pull with rebase
echo "Pulling latest changes..."
git pull --rebase origin "$BRANCH" 2>/dev/null || git pull origin "$BRANCH" 2>/dev/null || echo "No remote branch yet"

# Push
echo ""
echo "Pushing to remote..."
git push -u origin "$BRANCH"

echo ""
echo "Branch $BRANCH is now synced with origin."
```
