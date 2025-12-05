#!/bin/bash
# cmd-deps.sh - Check outdated dependencies
echo "=== Dependency Check ==="

[[ -f "composer.json" ]] && {
    echo -e "\n=== Composer ==="
    composer outdated --direct 2>/dev/null || echo "Run: composer install"
}

[[ -f "package.json" ]] && {
    echo -e "\n=== npm ==="
    if [[ -f "pnpm-lock.yaml" ]]; then pnpm outdated 2>/dev/null
    elif [[ -f "yarn.lock" ]]; then yarn outdated 2>/dev/null
    else npm outdated 2>/dev/null; fi
}

[[ -f "requirements.txt" || -f "pyproject.toml" ]] && {
    echo -e "\n=== pip ==="
    pip list --outdated 2>/dev/null | head -15
}

[[ -f "Cargo.toml" ]] && {
    echo -e "\n=== Cargo ==="
    cargo outdated -R 2>/dev/null || echo "Install: cargo install cargo-outdated"
}

[[ -f "go.mod" ]] && {
    echo -e "\n=== Go ==="
    go list -u -m all 2>/dev/null | grep '\[' | head -10
}

echo -e "\n=== Security ==="
[[ -f "package.json" ]] && npm audit --audit-level=moderate 2>/dev/null | tail -5
[[ -f "composer.json" ]] && composer audit 2>/dev/null | tail -5
