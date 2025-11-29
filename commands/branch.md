---
description: Create and switch to a new feature branch
allowed-tools: Bash
---

Create a new feature branch from the latest main/master.

Usage: /branch <branch-name>
Example: /branch feat/add-user-auth

```bash
NAME="$1"

if [[ -z "$NAME" ]]; then
    echo "Usage: /branch <branch-name>"
    echo ""
    echo "Examples:"
    echo "  /branch feat/add-login"
    echo "  /branch fix/payment-bug"
    echo "  /branch refactor/cleanup-api"
    exit 1
fi

# Get main branch name
MAIN=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d: -f2 | tr -d ' ')
if [[ -z "$MAIN" ]]; then
    MAIN="main"
fi

# Fetch latest
echo "Fetching latest from origin..."
git fetch origin "$MAIN" 2>/dev/null

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo ""
    echo "WARNING: You have uncommitted changes. Stashing them..."
    git stash
    STASHED=true
fi

# Create and switch to new branch from latest main
git checkout -b "$NAME" "origin/$MAIN"

if [[ "$STASHED" == "true" ]]; then
    echo ""
    echo "Restoring stashed changes..."
    git stash pop
fi

echo ""
echo "Created and switched to: $NAME"
echo "Based on: origin/$MAIN"
```
