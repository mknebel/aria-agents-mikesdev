#!/bin/bash
# cmd-env.sh - Environment check
echo "=== Environment Check ==="

# Find .env
ENV_FILE=""; EXAMPLE=""
[[ -f ".env" ]] && ENV_FILE=".env"
[[ -f ".env.local" ]] && ENV_FILE=".env.local"
for f in .env.example .env.sample .env.template; do [[ -f "$f" ]] && EXAMPLE="$f" && break; done

[[ -n "$ENV_FILE" ]] && echo "✓ $ENV_FILE" || echo "✗ No .env"
[[ -n "$EXAMPLE" ]] && echo "✓ $EXAMPLE"

# Compare
if [[ -n "$ENV_FILE" && -n "$EXAMPLE" ]]; then
    echo -e "\n=== Missing Variables ==="
    MISSING=$(comm -23 <(grep -E "^[A-Z_]+=" "$EXAMPLE" | cut -d= -f1 | sort) \
                       <(grep -E "^[A-Z_]+=" "$ENV_FILE" | cut -d= -f1 | sort))
    [[ -n "$MISSING" ]] && echo "$MISSING" | sed 's/^/  - /' || echo "✓ All defined"

    echo -e "\n=== Empty Variables ==="
    grep -E "^[A-Z_]+=$" "$ENV_FILE" 2>/dev/null | cut -d= -f1 | sed 's/^/  - /' || echo "✓ None empty"
fi

echo -e "\n=== Runtime ==="
for cmd in php node python composer npm; do
    command -v $cmd &>/dev/null && echo "✓ $cmd: $($cmd --version 2>&1 | head -1)"
done
