#!/bin/bash
# quality-gate.sh - Unified quality checker for aria workflow
# Usage: quality-gate.sh [path] [--fix] [--skip-tests]
#
# Runs: lint → static analysis → tests → security scan
# Returns: 0 = pass, 1 = fail

set -e

SCAN_PATH="${1:-.}"
FIX_MODE=""
SKIP_TESTS=""

for arg in "$@"; do
    case $arg in
        --fix) FIX_MODE="--fix" ;;
        --skip-tests) SKIP_TESTS="1" ;;
    esac
done

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

run_check() {
    local name="$1"
    local cmd="$2"
    local required="${3:-false}"

    echo -e "${BLUE}▶ $name${NC}"

    if eval "$cmd" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Passed${NC}"
        ((PASSED++))
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}  ✗ Failed (required)${NC}"
            ((FAILED++))
            return 1
        else
            echo -e "${YELLOW}  ⚠ Issues found${NC}"
            ((FAILED++))
            return 0
        fi
    fi
}

skip_check() {
    local name="$1"
    local reason="$2"
    echo -e "${YELLOW}▶ $name - SKIPPED ($reason)${NC}"
    ((SKIPPED++))
}

echo "════════════════════════════════════════════════════"
echo "🔍 QUALITY GATE"
echo "════════════════════════════════════════════════════"
echo "Path: $SCAN_PATH"
echo "Options: ${FIX_MODE:-none} ${SKIP_TESTS:+skip-tests}"
echo ""

# Detect project type
HAS_PHP=$([ -f "$SCAN_PATH/composer.json" ] && echo "1" || echo "")
HAS_JS=$([ -f "$SCAN_PATH/package.json" ] && echo "1" || echo "")
HAS_PYTHON=$([ -f "$SCAN_PATH/requirements.txt" ] || [ -f "$SCAN_PATH/pyproject.toml" ] && echo "1" || echo "")

echo "────────────────────────────────────────────────────"
echo "📋 LINTING"
echo "────────────────────────────────────────────────────"

# PHP Linting
if [ -n "$HAS_PHP" ]; then
    if command -v phpcs &> /dev/null; then
        run_check "PHP CodeSniffer" "phpcs --standard=PSR12 --colors -n $SCAN_PATH/src 2>/dev/null || phpcs --colors -n $SCAN_PATH 2>/dev/null"
    elif [ -f "$SCAN_PATH/vendor/bin/phpcs" ]; then
        run_check "PHP CodeSniffer" "$SCAN_PATH/vendor/bin/phpcs --standard=PSR12 -n $SCAN_PATH/src 2>/dev/null"
    else
        skip_check "PHP CodeSniffer" "not installed"
    fi
else
    skip_check "PHP Linting" "no composer.json"
fi

# JS/TS Linting
if [ -n "$HAS_JS" ]; then
    if [ -f "$SCAN_PATH/node_modules/.bin/eslint" ]; then
        run_check "ESLint" "cd $SCAN_PATH && npm run lint --if-present 2>/dev/null"
    elif command -v eslint &> /dev/null; then
        run_check "ESLint" "eslint $SCAN_PATH/src --ext .js,.ts,.jsx,.tsx 2>/dev/null"
    else
        skip_check "ESLint" "not installed"
    fi
else
    skip_check "JS Linting" "no package.json"
fi

# Python Linting
if [ -n "$HAS_PYTHON" ]; then
    if command -v ruff &> /dev/null; then
        run_check "Ruff" "ruff check $SCAN_PATH"
    elif command -v flake8 &> /dev/null; then
        run_check "Flake8" "flake8 $SCAN_PATH"
    else
        skip_check "Python Linting" "ruff/flake8 not installed"
    fi
fi

echo ""
echo "────────────────────────────────────────────────────"
echo "🔬 STATIC ANALYSIS"
echo "────────────────────────────────────────────────────"

# PHP Static Analysis
if [ -n "$HAS_PHP" ]; then
    if command -v phpstan &> /dev/null; then
        run_check "PHPStan" "phpstan analyse $SCAN_PATH/src --level=5 --no-progress 2>/dev/null"
    elif [ -f "$SCAN_PATH/vendor/bin/phpstan" ]; then
        run_check "PHPStan" "$SCAN_PATH/vendor/bin/phpstan analyse --level=5 --no-progress 2>/dev/null"
    else
        skip_check "PHPStan" "not installed"
    fi
fi

# TypeScript
if [ -n "$HAS_JS" ] && [ -f "$SCAN_PATH/tsconfig.json" ]; then
    if [ -f "$SCAN_PATH/node_modules/.bin/tsc" ]; then
        run_check "TypeScript" "cd $SCAN_PATH && npx tsc --noEmit 2>/dev/null"
    else
        skip_check "TypeScript" "tsc not installed"
    fi
fi

# Python Type Checking
if [ -n "$HAS_PYTHON" ]; then
    if command -v mypy &> /dev/null; then
        run_check "MyPy" "mypy $SCAN_PATH --ignore-missing-imports 2>/dev/null"
    else
        skip_check "MyPy" "not installed"
    fi
fi

echo ""
echo "────────────────────────────────────────────────────"
echo "🧪 TESTS"
echo "────────────────────────────────────────────────────"

if [ -n "$SKIP_TESTS" ]; then
    skip_check "All Tests" "skip-tests flag"
else
    # PHP Tests
    if [ -n "$HAS_PHP" ]; then
        if [ -f "$SCAN_PATH/vendor/bin/phpunit" ]; then
            run_check "PHPUnit" "$SCAN_PATH/vendor/bin/phpunit --colors=always 2>/dev/null" "true"
        elif [ -f "$SCAN_PATH/vendor/bin/pest" ]; then
            run_check "Pest" "$SCAN_PATH/vendor/bin/pest 2>/dev/null" "true"
        else
            skip_check "PHP Tests" "phpunit/pest not found"
        fi
    fi

    # JS Tests
    if [ -n "$HAS_JS" ]; then
        if grep -q '"test"' "$SCAN_PATH/package.json" 2>/dev/null; then
            run_check "npm test" "cd $SCAN_PATH && npm test 2>/dev/null" "true"
        else
            skip_check "JS Tests" "no test script"
        fi
    fi

    # Python Tests
    if [ -n "$HAS_PYTHON" ]; then
        if command -v pytest &> /dev/null; then
            run_check "Pytest" "pytest $SCAN_PATH -q 2>/dev/null" "true"
        else
            skip_check "Python Tests" "pytest not installed"
        fi
    fi
fi

echo ""
echo "────────────────────────────────────────────────────"
echo "🔒 SECURITY"
echo "────────────────────────────────────────────────────"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
if [ -f "$SCRIPT_DIR/security-scan.sh" ]; then
    "$SCRIPT_DIR/security-scan.sh" "$SCAN_PATH" && ((PASSED++)) || ((FAILED++))
else
    run_check "Security Scan" "~/.claude/scripts/security-scan.sh $SCAN_PATH"
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════"
echo "📊 SUMMARY"
echo "════════════════════════════════════════════════════"
echo -e "Passed:  ${GREEN}$PASSED${NC}"
echo -e "Failed:  ${RED}$FAILED${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
echo ""

# Save result
RESULT="PASSED=$PASSED FAILED=$FAILED SKIPPED=$SKIPPED"
echo "$RESULT" > "$VAR_DIR/quality_gate_last"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}❌ QUALITY GATE FAILED${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Fix issues above"
    echo "  2. Run: quality-gate.sh $SCAN_PATH --fix"
    echo "  3. Or escalate: /thinking \"fix quality issues\""
    exit 1
else
    echo -e "${GREEN}✅ QUALITY GATE PASSED${NC}"
    exit 0
fi
