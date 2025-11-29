---
description: Check project index status and freshness
allowed-tools: Bash
---

Check the status of project indexes:

```bash
echo "=== Project Indexes ==="
ls -lah ~/.claude/project-indexes/ 2>/dev/null || echo "No indexes found"

echo ""
echo "=== Current Project Index ==="
PROJECT_ROOT="$(pwd)"
INDEX_NAME=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//')
INDEX_FILE="$HOME/.claude/project-indexes/${INDEX_NAME}.json"

if [[ -f "$INDEX_FILE" ]]; then
    echo "Index: $INDEX_FILE"
    echo "Size: $(du -h "$INDEX_FILE" | cut -f1)"
    echo "Age: $(( ($(date +%s) - $(stat -c %Y "$INDEX_FILE")) / 60 )) minutes"
    echo "Files indexed: $(jq '.file_count' "$INDEX_FILE" 2>/dev/null)"
    echo ""
    echo "Categories:"
    jq -r '.categories | keys[]' "$INDEX_FILE" 2>/dev/null | while read cat; do
        COUNT=$(jq ".categories.$cat | length" "$INDEX_FILE" 2>/dev/null)
        echo "  - $cat: $COUNT files"
    done
else
    echo "No index for current project"
    echo "Run /index-project to create one"
fi
```
