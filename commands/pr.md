---
description: Create a pull request for current branch
allowed-tools: Bash
---

Create a pull request for the current branch.

Steps:
1. Check current branch and ensure it's not main/master
2. Check for uncommitted changes (warn if any)
3. Push branch to remote if needed
4. Create PR using gh cli

```bash
BRANCH=$(git branch --show-current)
MAIN=$(git remote show origin | grep 'HEAD branch' | cut -d: -f2 | tr -d ' ')

if [[ "$BRANCH" == "$MAIN" ]] || [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
    echo "ERROR: Cannot create PR from $BRANCH. Create a feature branch first."
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo "WARNING: You have uncommitted changes:"
    git status --short
    echo ""
    echo "Consider committing these first."
fi

# Push if needed
git push -u origin "$BRANCH" 2>/dev/null || true

echo ""
echo "Ready to create PR from: $BRANCH → $MAIN"
```

After running the check, create the PR with:
- A clear title summarizing the changes
- A body with ## Summary and ## Test plan sections
- Use `gh pr create`
