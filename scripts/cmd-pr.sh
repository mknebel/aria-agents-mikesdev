#!/bin/bash
# cmd-pr.sh - PR pre-flight checks
set -e

BRANCH=$(git branch --show-current)
MAIN=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d: -f2 | tr -d ' ')
[[ -z "$MAIN" ]] && MAIN="main"

echo "=== PR Pre-flight: $BRANCH → $MAIN ==="

[[ "$BRANCH" == "$MAIN" || "$BRANCH" == "main" || "$BRANCH" == "master" ]] && {
    echo "ERROR: Cannot PR from $BRANCH. Use /branch first."; exit 1
}

[[ -n $(git status --porcelain) ]] && {
    echo "WARNING: Uncommitted changes:"; git status --short; echo ""
}

PASS=true

# Lint
echo "1. Lint..."
if [[ -f ".eslintrc.js" || -f ".eslintrc.json" || -f "eslint.config.js" ]]; then
    npx eslint . --ext .js,.jsx,.ts,.tsx --quiet 2>/dev/null && echo "   ✓ ESLint" || PASS=false
elif [[ -f "phpcs.xml" || -f "phpcs.xml.dist" ]]; then
    ./vendor/bin/phpcs --report=summary 2>/dev/null && echo "   ✓ PHPCS" || PASS=false
fi

# Types
echo "2. Types..."
if [[ -f "tsconfig.json" ]]; then
    npx tsc --noEmit 2>/dev/null && echo "   ✓ TypeScript" || PASS=false
elif [[ -f "phpstan.neon" || -f "phpstan.neon.dist" ]]; then
    ./vendor/bin/phpstan analyse --no-progress 2>/dev/null && echo "   ✓ PHPStan" || PASS=false
fi

# Tests
echo "3. Tests..."
if [[ -f "phpunit.xml" || -f "phpunit.xml.dist" ]]; then
    ./vendor/bin/phpunit --stop-on-failure 2>/dev/null && echo "   ✓ PHPUnit" || PASS=false
elif [[ -f "package.json" ]] && grep -q '"test"' package.json; then
    npm test 2>/dev/null && echo "   ✓ Tests" || PASS=false
fi

# Secrets
echo "4. Security..."
SECRETS=$(git diff "$MAIN"...HEAD | grep -iE "(password|secret|api_key|token)\s*[=:]\s*['\"][^'\"]{8,}" | head -3)
[[ -n "$SECRETS" ]] && { echo "   ✗ Secrets detected!"; PASS=false; } || echo "   ✓ No secrets"

echo ""
[[ "$PASS" == "true" ]] && echo "✓ All checks passed!" || echo "✗ Some checks failed"

git push -u origin "$BRANCH" 2>/dev/null || true
echo "Ready: gh pr create --title \"...\" --body \"...\""
