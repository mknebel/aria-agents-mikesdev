#!/bin/bash
# cmd-branch.sh - Create feature branch from main
NAME="$1"
[[ -z "$NAME" ]] && { echo "Usage: /branch <name>"; exit 1; }

MAIN=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d: -f2 | tr -d ' ')
[[ -z "$MAIN" ]] && MAIN="main"

echo "Fetching origin/$MAIN..."
git fetch origin "$MAIN" 2>/dev/null

STASHED=""
[[ -n $(git status --porcelain) ]] && { echo "Stashing changes..."; git stash; STASHED=1; }

git checkout -b "$NAME" "origin/$MAIN"

[[ -n "$STASHED" ]] && { echo "Restoring stash..."; git stash pop; }

echo "Created: $NAME (from origin/$MAIN)"
