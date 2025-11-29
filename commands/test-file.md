---
description: Run tests for a specific file
allowed-tools: Bash
---

Run tests for a specific file or pattern.

Usage: /test-file <file-or-pattern>
Example: /test-file tests/PaymentTest.php

```bash
TARGET="$1"

if [[ -z "$TARGET" ]]; then
    echo "Usage: /test-file <file-or-pattern>"
    echo ""
    echo "Examples:"
    echo "  /test-file tests/PaymentTest.php"
    echo "  /test-file src/components/Button.test.tsx"
    echo "  /test-file test_payment.py"
    exit 1
fi

echo "=== Running tests for: $TARGET ==="
echo ""

# Detect framework and run with target
if [[ -f "phpunit.xml" ]] || [[ -f "phpunit.xml.dist" ]]; then
    ./vendor/bin/phpunit "$TARGET"
elif [[ -f "jest.config.js" ]] || [[ -f "jest.config.ts" ]]; then
    npx jest "$TARGET"
elif [[ -f "vitest.config.js" ]] || [[ -f "vitest.config.ts" ]]; then
    npx vitest run "$TARGET"
elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
    pytest "$TARGET"
elif [[ -f "Cargo.toml" ]]; then
    cargo test "$TARGET"
elif [[ -f "go.mod" ]]; then
    go test -run "$TARGET" ./...
else
    echo "No test framework detected. Running file directly..."
    if [[ "$TARGET" == *.php ]]; then
        php "$TARGET"
    elif [[ "$TARGET" == *.py ]]; then
        python "$TARGET"
    elif [[ "$TARGET" == *.js ]]; then
        node "$TARGET"
    else
        echo "Don't know how to run: $TARGET"
    fi
fi
```
