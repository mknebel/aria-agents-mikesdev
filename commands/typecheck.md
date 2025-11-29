---
description: Run type checker (TypeScript, PHPStan, mypy, etc.)
allowed-tools: Bash
---

Run type checking for the project.

```bash
echo "=== Running Type Check ==="

# TypeScript
if [[ -f "tsconfig.json" ]]; then
    echo "Found: TypeScript"
    npx tsc --noEmit

# PHP
elif [[ -f "phpstan.neon" ]] || [[ -f "phpstan.neon.dist" ]]; then
    echo "Found: PHPStan"
    ./vendor/bin/phpstan analyse
elif [[ -f "psalm.xml" ]] || [[ -f "psalm.xml.dist" ]]; then
    echo "Found: Psalm"
    ./vendor/bin/psalm

# Python
elif [[ -f "mypy.ini" ]] || [[ -f ".mypy.ini" ]] || ([[ -f "pyproject.toml" ]] && grep -q "mypy" pyproject.toml 2>/dev/null); then
    echo "Found: mypy"
    mypy .
elif [[ -f "pyrightconfig.json" ]] || ([[ -f "pyproject.toml" ]] && grep -q "pyright" pyproject.toml 2>/dev/null); then
    echo "Found: Pyright"
    pyright

# Flow (JavaScript)
elif [[ -f ".flowconfig" ]]; then
    echo "Found: Flow"
    npx flow check

# Generic package.json script
elif [[ -f "package.json" ]] && grep -q '"typecheck"' package.json; then
    echo "Found: npm typecheck script"
    npm run typecheck

else
    echo "No type checker configuration detected."
    echo ""
    echo "Supported type checkers:"
    echo "  TypeScript: tsc (tsconfig.json)"
    echo "  PHP: phpstan, psalm"
    echo "  Python: mypy, pyright"
    echo "  JavaScript: flow"
fi
```
