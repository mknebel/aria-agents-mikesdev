#!/bin/bash
# cmd-lint.sh - Auto-detect and run linter
echo "=== Linting ==="

# PHP
[[ -f "phpcs.xml" || -f "phpcs.xml.dist" ]] && { echo "PHPCS:"; ./vendor/bin/phpcs; exit; }
[[ -f "phpstan.neon" || -f "phpstan.neon.dist" ]] && { echo "PHPStan:"; ./vendor/bin/phpstan analyse; exit; }
[[ -f ".php-cs-fixer.php" ]] && { echo "PHP-CS-Fixer:"; ./vendor/bin/php-cs-fixer fix --dry-run --diff; exit; }

# JS/TS
[[ -f ".eslintrc.js" || -f ".eslintrc.json" || -f "eslint.config.js" ]] && { echo "ESLint:"; npx eslint . --ext .js,.jsx,.ts,.tsx; exit; }
[[ -f "biome.json" ]] && { echo "Biome:"; npx biome check .; exit; }

# Python
[[ -f ".flake8" ]] && { echo "Flake8:"; flake8; exit; }
[[ -f "pyproject.toml" ]] && grep -q "ruff" pyproject.toml && { echo "Ruff:"; ruff check .; exit; }

# Rust/Go
[[ -f "Cargo.toml" ]] && { echo "Clippy:"; cargo clippy; exit; }
[[ -f "go.mod" ]] && { echo "Go vet:"; go vet ./...; exit; }

# Fallback
[[ -f "package.json" ]] && grep -q '"lint"' package.json && { npm run lint; exit; }

echo "No linter detected. Supported: phpcs, phpstan, eslint, biome, flake8, ruff, clippy"
