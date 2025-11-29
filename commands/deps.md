---
description: Check for outdated dependencies
allowed-tools: Bash
---

Check for outdated dependencies.

```bash
echo "=== Dependency Check ==="
echo ""

# PHP/Composer
if [[ -f "composer.json" ]]; then
    echo "=== Composer (PHP) ==="
    if [[ -f "composer.lock" ]]; then
        composer outdated --direct 2>/dev/null || echo "Run: composer install first"
    else
        echo "No composer.lock - run: composer install"
    fi
    echo ""
fi

# Node/npm
if [[ -f "package.json" ]]; then
    echo "=== npm (Node.js) ==="
    if [[ -f "package-lock.json" ]]; then
        npm outdated 2>/dev/null || echo "All packages up to date"
    elif [[ -f "yarn.lock" ]]; then
        echo "Using Yarn:"
        yarn outdated 2>/dev/null || echo "All packages up to date"
    elif [[ -f "pnpm-lock.yaml" ]]; then
        echo "Using pnpm:"
        pnpm outdated 2>/dev/null || echo "All packages up to date"
    else
        echo "No lock file - run: npm install"
    fi
    echo ""
fi

# Python
if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
    echo "=== pip (Python) ==="
    if command -v pip &> /dev/null; then
        pip list --outdated 2>/dev/null | head -20 || echo "Could not check"
    else
        echo "pip not available"
    fi
    echo ""
fi

# Rust
if [[ -f "Cargo.toml" ]]; then
    echo "=== Cargo (Rust) ==="
    if command -v cargo-outdated &> /dev/null; then
        cargo outdated -R 2>/dev/null || echo "Run: cargo install cargo-outdated"
    else
        echo "Install cargo-outdated: cargo install cargo-outdated"
    fi
    echo ""
fi

# Go
if [[ -f "go.mod" ]]; then
    echo "=== Go Modules ==="
    go list -u -m all 2>/dev/null | grep '\[' | head -20 || echo "All modules up to date"
    echo ""
fi

echo "=== Security Advisories ==="
if [[ -f "package.json" ]]; then
    echo "npm audit:"
    npm audit --audit-level=moderate 2>/dev/null | tail -10 || echo "No issues"
fi
if [[ -f "composer.json" ]]; then
    echo ""
    echo "composer audit:"
    composer audit 2>/dev/null || echo "Audit not available (composer 2.4+)"
fi
```
