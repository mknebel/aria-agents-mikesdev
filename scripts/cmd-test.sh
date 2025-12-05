#!/bin/bash
# cmd-test.sh - Auto-detect and run tests
ARGS="$@"
echo "=== Testing ==="

[[ -f "phpunit.xml" || -f "phpunit.xml.dist" ]] && { ./vendor/bin/phpunit $ARGS; exit; }
[[ -f "jest.config.js" || -f "jest.config.ts" ]] && { npx jest $ARGS; exit; }
[[ -f "vitest.config.js" || -f "vitest.config.ts" ]] && { npx vitest run $ARGS; exit; }
[[ -f "pytest.ini" || -f "pyproject.toml" ]] && { pytest $ARGS; exit; }
[[ -f "Cargo.toml" ]] && { cargo test $ARGS; exit; }
[[ -f "go.mod" ]] && { go test ./... $ARGS; exit; }
[[ -f "package.json" ]] && grep -q '"test"' package.json && { npm test -- $ARGS; exit; }

echo "No test framework detected."
