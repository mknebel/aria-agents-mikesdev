---
description: Run tests in watch mode (auto-rerun on changes)
allowed-tools: Bash
---

Run tests in watch mode - automatically re-runs when files change.

```bash
echo "=== Starting Test Watch Mode ==="

if [[ -f "phpunit.xml" ]] || [[ -f "phpunit.xml.dist" ]]; then
    echo "PHPUnit doesn't have built-in watch. Use: phpunit-watcher watch"
    echo "Install: composer require --dev spatie/phpunit-watcher"
    if command -v phpunit-watcher &> /dev/null; then
        phpunit-watcher watch
    fi
elif [[ -f "jest.config.js" ]] || [[ -f "jest.config.ts" ]]; then
    npx jest --watch
elif [[ -f "vitest.config.js" ]] || [[ -f "vitest.config.ts" ]]; then
    npx vitest
elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
    echo "pytest watch mode requires pytest-watch"
    echo "Install: pip install pytest-watch"
    if command -v ptw &> /dev/null; then
        ptw
    else
        pytest
    fi
elif [[ -f "Cargo.toml" ]]; then
    echo "Cargo watch mode requires cargo-watch"
    echo "Install: cargo install cargo-watch"
    if command -v cargo-watch &> /dev/null; then
        cargo watch -x test
    else
        cargo test
    fi
elif [[ -f "go.mod" ]]; then
    echo "Go doesn't have built-in watch. Running once..."
    go test ./...
else
    echo "No test framework detected."
fi
```
