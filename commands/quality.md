---
description: Run quality gate (lint, tests, security scan)
argument-hint: [path] [--fix] [--skip-tests]
---

# Quality Gate

Run unified quality checks:

```bash
~/.claude/scripts/quality-gate.sh $ARGUMENTS
```

## What It Checks

| Check | Tool |
|-------|------|
| Linting | phpcs, eslint, ruff |
| Static Analysis | phpstan, tsc, mypy |
| Tests | phpunit, jest, pytest |
| Security | OWASP patterns, dependency audit |

## Options

| Flag | Purpose |
|------|---------|
| `--fix` | Auto-fix where possible |
| `--skip-tests` | Skip test execution |

## On Failure

- Minor issues → Fix and re-run
- Complex issues → `/thinking "fix quality issues"`
