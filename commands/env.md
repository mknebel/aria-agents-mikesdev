---
description: Check environment setup and missing variables
allowed-tools: Bash
---

Check environment configuration.

```bash
echo "=== Environment Check ==="
echo ""

# Check for .env file
if [[ -f ".env" ]]; then
    echo "✓ .env file exists"
    ENV_FILE=".env"
elif [[ -f ".env.local" ]]; then
    echo "✓ .env.local file exists"
    ENV_FILE=".env.local"
else
    echo "✗ No .env file found"
    ENV_FILE=""
fi

# Check for example file
EXAMPLE_FILE=""
for f in .env.example .env.sample .env.template .env.dist; do
    if [[ -f "$f" ]]; then
        EXAMPLE_FILE="$f"
        echo "✓ Example file: $f"
        break
    fi
done

echo ""

# Compare .env with example
if [[ -n "$ENV_FILE" && -n "$EXAMPLE_FILE" ]]; then
    echo "=== Missing Variables ==="

    # Get keys from example (ignore comments and empty lines)
    EXAMPLE_KEYS=$(grep -E "^[A-Z_]+=" "$EXAMPLE_FILE" | cut -d= -f1 | sort)
    ENV_KEYS=$(grep -E "^[A-Z_]+=" "$ENV_FILE" | cut -d= -f1 | sort)

    MISSING=$(comm -23 <(echo "$EXAMPLE_KEYS") <(echo "$ENV_KEYS"))

    if [[ -n "$MISSING" ]]; then
        echo "Variables in $EXAMPLE_FILE but not in $ENV_FILE:"
        echo "$MISSING" | while read key; do
            echo "  - $key"
        done
    else
        echo "✓ All example variables are defined"
    fi

    echo ""
    echo "=== Empty Variables ==="
    grep -E "^[A-Z_]+=$" "$ENV_FILE" 2>/dev/null | cut -d= -f1 | while read key; do
        echo "  - $key (empty)"
    done || echo "✓ No empty variables"
fi

echo ""
echo "=== Runtime Checks ==="

# Check common tools
for cmd in php node python composer npm; do
    if command -v $cmd &> /dev/null; then
        VERSION=$($cmd --version 2>&1 | head -1)
        echo "✓ $cmd: $VERSION"
    fi
done

# Check database connection (if .env has DB config)
if [[ -n "$ENV_FILE" ]] && grep -q "DB_HOST\|DATABASE_URL" "$ENV_FILE" 2>/dev/null; then
    echo ""
    echo "=== Database ==="
    if grep -q "DB_HOST" "$ENV_FILE"; then
        DB_HOST=$(grep "^DB_HOST=" "$ENV_FILE" | cut -d= -f2)
        DB_PORT=$(grep "^DB_PORT=" "$ENV_FILE" | cut -d= -f2)
        echo "Database host: $DB_HOST:${DB_PORT:-3306}"
    fi
fi
```
