---
description: Run tests in watch mode
---

```bash
echo "=== Test Watch ==="
[[ -f "jest.config.js" ]] && { npx jest --watch; exit; }
[[ -f "vitest.config.js" ]] && { npx vitest; exit; }
[[ -f "phpunit.xml" ]] && { phpunit-watcher watch 2>/dev/null || echo "Install: composer require spatie/phpunit-watcher"; exit; }
[[ -f "pytest.ini" || -f "pyproject.toml" ]] && { ptw 2>/dev/null || pytest; exit; }
[[ -f "Cargo.toml" ]] && { cargo watch -x test 2>/dev/null || cargo test; exit; }
echo "No watch mode available"
```
