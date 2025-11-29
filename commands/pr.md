---
description: Create a pull request with pre-commit checks
allowed-tools: Bash
---

Create a pull request for the current branch with quality checks.

```bash
BRANCH=$(git branch --show-current)
MAIN=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d: -f2 | tr -d ' ')
[[ -z "$MAIN" ]] && MAIN="main"

echo "=== PR Pre-flight Checks ==="
echo ""

if [[ "$BRANCH" == "$MAIN" ]] || [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
    echo "ERROR: Cannot create PR from $BRANCH. Create a feature branch first."
    echo "Use: /branch <feature-name>"
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo "WARNING: Uncommitted changes detected:"
    git status --short
    echo ""
fi

echo "=== Running Quality Checks ==="
CHECKS_PASSED=true

# 1. Lint check
echo ""
echo "1. Lint..."
if [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || [[ -f "eslint.config.js" ]]; then
    npx eslint . --ext .js,.jsx,.ts,.tsx --quiet 2>/dev/null && echo "   ✓ ESLint passed" || { echo "   ✗ ESLint failed"; CHECKS_PASSED=false; }
elif [[ -f "phpcs.xml" ]] || [[ -f "phpcs.xml.dist" ]]; then
    ./vendor/bin/phpcs --report=summary 2>/dev/null && echo "   ✓ PHPCS passed" || { echo "   ✗ PHPCS failed"; CHECKS_PASSED=false; }
else
    echo "   - No linter configured (skipped)"
fi

# 2. Type check
echo ""
echo "2. Type check..."
if [[ -f "tsconfig.json" ]]; then
    npx tsc --noEmit 2>/dev/null && echo "   ✓ TypeScript passed" || { echo "   ✗ TypeScript failed"; CHECKS_PASSED=false; }
elif [[ -f "phpstan.neon" ]] || [[ -f "phpstan.neon.dist" ]]; then
    ./vendor/bin/phpstan analyse --no-progress 2>/dev/null && echo "   ✓ PHPStan passed" || { echo "   ✗ PHPStan failed"; CHECKS_PASSED=false; }
else
    echo "   - No type checker configured (skipped)"
fi

# 3. Tests
echo ""
echo "3. Tests..."
if [[ -f "phpunit.xml" ]] || [[ -f "phpunit.xml.dist" ]]; then
    ./vendor/bin/phpunit --stop-on-failure 2>/dev/null && echo "   ✓ PHPUnit passed" || { echo "   ✗ Tests failed"; CHECKS_PASSED=false; }
elif [[ -f "jest.config.js" ]] || [[ -f "jest.config.ts" ]]; then
    npx jest --passWithNoTests 2>/dev/null && echo "   ✓ Jest passed" || { echo "   ✗ Tests failed"; CHECKS_PASSED=false; }
elif [[ -f "package.json" ]] && grep -q '"test"' package.json; then
    npm test 2>/dev/null && echo "   ✓ Tests passed" || { echo "   ✗ Tests failed"; CHECKS_PASSED=false; }
else
    echo "   - No test framework configured (skipped)"
fi

# 4. Security quick check
echo ""
echo "4. Security..."
SECRETS=$(git diff "$MAIN"...HEAD | grep -iE "(password|secret|api_key|token)\s*[=:]\s*['\"][^'\"]{8,}" | head -3)
if [[ -n "$SECRETS" ]]; then
    echo "   ✗ Potential secrets detected in diff!"
    echo "$SECRETS"
    CHECKS_PASSED=false
else
    echo "   ✓ No obvious secrets in diff"
fi

echo ""
echo "=== Summary ==="
if [[ "$CHECKS_PASSED" == "true" ]]; then
    echo "✓ All checks passed!"
else
    echo "✗ Some checks failed. Review above and fix before PR."
    echo ""
    echo "To skip checks and create PR anyway, use: gh pr create"
fi

# Push branch
echo ""
echo "Pushing branch..."
git push -u origin "$BRANCH" 2>/dev/null || true

echo ""
echo "Ready to create PR: $BRANCH → $MAIN"
```

After checks pass, create the PR with:
- A clear title summarizing the changes
- A body with ## Summary and ## Test plan sections
- Use `gh pr create`
