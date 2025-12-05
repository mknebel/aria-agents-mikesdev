#!/bin/bash
# cmd-template.sh - Detect framework and show template path
echo "=== Framework Detection ==="

[[ -f "bin/cake" || -f "config/app.php" ]] && { echo "CakePHP → ~/.claude/templates/cakephp.md"; exit; }
[[ -f "artisan" ]] && { echo "Laravel → ~/.claude/templates/laravel.md"; exit; }
[[ -f "next.config.js" || -f "next.config.ts" ]] && { echo "Next.js → ~/.claude/templates/nextjs.md"; exit; }
[[ -f "manage.py" ]] && { echo "Django → ~/.claude/templates/python.md"; exit; }
[[ -f "package.json" ]] && grep -q '"react"' package.json && { echo "React → ~/.claude/templates/react.md"; exit; }
[[ -f "package.json" ]] && grep -q '"express"' package.json && { echo "Node.js → ~/.claude/templates/nodejs.md"; exit; }
[[ -f "pyproject.toml" || -f "requirements.txt" ]] && { echo "Python → ~/.claude/templates/python.md"; exit; }

echo "No framework detected. Templates: ~/.claude/templates/"
