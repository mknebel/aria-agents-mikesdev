---
description: Fast lookup of function or class from project index
allowed-tools: Bash
---

Look up a function or class name in the project index.

Usage: /lookup <name>

```bash
NAME="$1"
if [[ -z "$NAME" ]]; then
    echo "Usage: /lookup <function_or_class_name>"
    exit 1
fi

PROJECT_ROOT="$(pwd)"
INDEX_NAME=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//')
INDEX_FILE="$HOME/.claude/project-indexes/${INDEX_NAME}.json"

if [[ ! -f "$INDEX_FILE" ]]; then
    echo "No index for current project. Run /index-project first."
    exit 1
fi

echo "=== Looking up: $NAME ==="

# Check function index
FUNC=$(jq -r ".function_index[\"$NAME\"] // empty" "$INDEX_FILE" 2>/dev/null)
if [[ -n "$FUNC" ]]; then
    echo "Function found: $FUNC"
fi

# Check class index
CLASS=$(jq -r ".class_index[\"$NAME\"] // empty" "$INDEX_FILE" 2>/dev/null)
if [[ -n "$CLASS" ]]; then
    echo "Class found: $CLASS"
fi

# Fuzzy search if exact match not found
if [[ -z "$FUNC" && -z "$CLASS" ]]; then
    echo "No exact match. Searching for similar names..."
    echo ""
    echo "Functions containing '$NAME':"
    jq -r ".function_index | to_entries[] | select(.key | test(\"$NAME\"; \"i\")) | \"  \(.key) -> \(.value)\"" "$INDEX_FILE" 2>/dev/null | head -10
    echo ""
    echo "Classes containing '$NAME':"
    jq -r ".class_index | to_entries[] | select(.key | test(\"$NAME\"; \"i\")) | \"  \(.key) -> \(.value)\"" "$INDEX_FILE" 2>/dev/null | head -10
fi
```
