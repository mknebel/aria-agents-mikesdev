#!/bin/bash
# cmd-typecheck.sh - Auto-detect and run type checker
echo "=== Type Check ==="

[[ -f "tsconfig.json" ]] && { echo "TypeScript:"; npx tsc --noEmit; exit; }
[[ -f "phpstan.neon" || -f "phpstan.neon.dist" ]] && { echo "PHPStan:"; ./vendor/bin/phpstan analyse; exit; }
[[ -f "psalm.xml" ]] && { echo "Psalm:"; ./vendor/bin/psalm; exit; }
[[ -f "mypy.ini" || -f ".mypy.ini" ]] && { echo "mypy:"; mypy .; exit; }
[[ -f "pyrightconfig.json" ]] && { echo "Pyright:"; pyright; exit; }
[[ -f ".flowconfig" ]] && { echo "Flow:"; npx flow check; exit; }
[[ -f "package.json" ]] && grep -q '"typecheck"' package.json && { npm run typecheck; exit; }

echo "No type checker detected. Supported: tsc, phpstan, psalm, mypy, pyright, flow"
