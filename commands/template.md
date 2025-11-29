---
description: Load framework-specific rules for current project
allowed-tools: Bash, Read
---

Detect the project framework and load appropriate rules/conventions.

```bash
echo "=== Detecting Framework ==="

TEMPLATE=""

# CakePHP
if [[ -f "bin/cake" ]] || [[ -f "bin/cake.php" ]] || [[ -f "config/app.php" && -d "src/Controller" ]]; then
    TEMPLATE="cakephp"
    echo "Detected: CakePHP"

# Laravel
elif [[ -f "artisan" ]] || [[ -f "bootstrap/app.php" ]]; then
    TEMPLATE="laravel"
    echo "Detected: Laravel"

# Next.js
elif [[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]] || [[ -f "next.config.mjs" ]]; then
    TEMPLATE="nextjs"
    echo "Detected: Next.js"

# React (generic)
elif [[ -f "package.json" ]] && grep -q '"react"' package.json 2>/dev/null; then
    TEMPLATE="react"
    echo "Detected: React"

# Python
elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
    TEMPLATE="python"
    echo "Detected: Python"

# Django
elif [[ -f "manage.py" ]] && grep -q "django" manage.py 2>/dev/null; then
    TEMPLATE="django"
    echo "Detected: Django (using Python template)"
    TEMPLATE="python"

# Express/Node
elif [[ -f "package.json" ]] && grep -q '"express"' package.json 2>/dev/null; then
    TEMPLATE="nodejs"
    echo "Detected: Node.js/Express"

else
    echo "No specific framework detected."
    echo ""
    echo "Available templates:"
    ls -1 ~/.claude/templates/*.md 2>/dev/null | xargs -n1 basename | sed 's/.md$//'
    exit 0
fi

echo ""
echo "Template: ~/.claude/templates/${TEMPLATE}.md"
```

After detection, read and display the template content so you have the framework conventions loaded into context.

If the user wants to apply this to their project CLAUDE.md, offer to append the relevant sections.
