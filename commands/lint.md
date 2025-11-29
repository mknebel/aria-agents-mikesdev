---
description: Run project linter (auto-detects framework)
allowed-tools: Bash
---

Detect and run the appropriate linter for this project.

```bash
echo "=== Detecting Linter ==="

# PHP
if [[ -f "phpcs.xml" ]] || [[ -f "phpcs.xml.dist" ]] || [[ -f ".phpcs.xml" ]]; then
    echo "Found: PHP_CodeSniffer"
    ./vendor/bin/phpcs
elif [[ -f "phpstan.neon" ]] || [[ -f "phpstan.neon.dist" ]]; then
    echo "Found: PHPStan"
    ./vendor/bin/phpstan analyse
elif [[ -f ".php-cs-fixer.php" ]] || [[ -f ".php-cs-fixer.dist.php" ]]; then
    echo "Found: PHP-CS-Fixer"
    ./vendor/bin/php-cs-fixer fix --dry-run --diff

# JavaScript/TypeScript
elif [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || [[ -f ".eslintrc" ]] || [[ -f "eslint.config.js" ]]; then
    echo "Found: ESLint"
    npx eslint . --ext .js,.jsx,.ts,.tsx
elif [[ -f "biome.json" ]]; then
    echo "Found: Biome"
    npx biome check .

# Python
elif [[ -f ".flake8" ]] || [[ -f "setup.cfg" ]] && grep -q "flake8" setup.cfg 2>/dev/null; then
    echo "Found: Flake8"
    flake8
elif [[ -f "pyproject.toml" ]] && grep -q "ruff" pyproject.toml 2>/dev/null; then
    echo "Found: Ruff"
    ruff check .
elif [[ -f ".pylintrc" ]] || [[ -f "pyproject.toml" ]]; then
    echo "Found: Pylint"
    pylint **/*.py

# Rust
elif [[ -f "Cargo.toml" ]]; then
    echo "Found: Clippy (Rust)"
    cargo clippy

# Go
elif [[ -f "go.mod" ]]; then
    echo "Found: Go vet + staticcheck"
    go vet ./...
    if command -v staticcheck &> /dev/null; then
        staticcheck ./...
    fi

# Generic
elif [[ -f "package.json" ]] && grep -q '"lint"' package.json; then
    echo "Found: npm lint script"
    npm run lint

else
    echo "No linter configuration detected."
    echo ""
    echo "Supported linters:"
    echo "  PHP: phpcs, phpstan, php-cs-fixer"
    echo "  JS/TS: eslint, biome"
    echo "  Python: flake8, ruff, pylint"
    echo "  Rust: clippy"
    echo "  Go: go vet, staticcheck"
fi
```
