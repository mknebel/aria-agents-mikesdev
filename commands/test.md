---
description: Run tests for current project (auto-detects framework)
allowed-tools: Bash
---

Detect the test framework and run tests.

```bash
echo "=== Detecting Test Framework ==="

# Check for various test frameworks
if [[ -f "phpunit.xml" ]] || [[ -f "phpunit.xml.dist" ]]; then
    echo "Found: PHPUnit"
    RUNNER="./vendor/bin/phpunit"
    if [[ ! -f "$RUNNER" ]]; then
        RUNNER="phpunit"
    fi
elif [[ -f "package.json" ]] && grep -q '"test"' package.json; then
    echo "Found: npm test script"
    RUNNER="npm test"
elif [[ -f "jest.config.js" ]] || [[ -f "jest.config.ts" ]]; then
    echo "Found: Jest"
    RUNNER="npx jest"
elif [[ -f "vitest.config.js" ]] || [[ -f "vitest.config.ts" ]]; then
    echo "Found: Vitest"
    RUNNER="npx vitest run"
elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]] || [[ -d "tests" && -f "tests/__init__.py" ]]; then
    echo "Found: pytest"
    RUNNER="pytest"
elif [[ -f "Cargo.toml" ]]; then
    echo "Found: Cargo (Rust)"
    RUNNER="cargo test"
elif [[ -f "go.mod" ]]; then
    echo "Found: Go"
    RUNNER="go test ./..."
else
    echo "No test framework detected."
    echo ""
    echo "Supported frameworks:"
    echo "  - PHPUnit (phpunit.xml)"
    echo "  - Jest (jest.config.js)"
    echo "  - Vitest (vitest.config.js)"
    echo "  - pytest (pytest.ini or tests/)"
    echo "  - Cargo (Cargo.toml)"
    echo "  - Go (go.mod)"
    echo "  - npm test (package.json with test script)"
    exit 1
fi

echo ""
echo "=== Running: $RUNNER ==="
echo ""
$RUNNER
```

If a specific test file or pattern is provided as an argument, pass it to the test runner.
