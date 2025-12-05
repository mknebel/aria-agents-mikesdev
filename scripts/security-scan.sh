#!/bin/bash
# security-scan.sh - Quick OWASP big-hitter security checks
# Usage: security-scan.sh [path] [--strict]
#
# Scans for common vulnerabilities (OWASP Top 10)
# Returns: 0 = pass, 1 = warnings, 2 = critical

set -e

SCAN_PATH="${1:-.}"
STRICT="${2:-}"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

CRITICAL=0
WARNINGS=0
OUTPUT=""

log() { OUTPUT+="$1\n"; echo -e "$1"; }

scan_pattern() {
    local name="$1"
    local pattern="$2"
    local severity="$3"
    local glob="${4:-*}"

    local matches=$(grep -rn --include="$glob" -E "$pattern" "$SCAN_PATH" 2>/dev/null | head -20 || true)

    if [ -n "$matches" ]; then
        if [ "$severity" = "CRITICAL" ]; then
            log "${RED}[CRITICAL] $name${NC}"
            ((CRITICAL++)) || true
        else
            log "${YELLOW}[WARNING] $name${NC}"
            ((WARNINGS++)) || true
        fi
        echo "$matches" | head -5
        local count=$(echo "$matches" | wc -l)
        [ "$count" -gt 5 ] && echo "  ... and $((count-5)) more"
        echo ""
    fi
}

echo "════════════════════════════════════════════"
echo "🔒 SECURITY SCAN - OWASP Big Hitters"
echo "════════════════════════════════════════════"
echo "Path: $SCAN_PATH"
echo ""

# SQL Injection
scan_pattern "SQL Injection - Raw query with variables" \
    '(mysql_query|mysqli_query|->query)\s*\([^)]*\$' "CRITICAL" "*.php"

scan_pattern "SQL Injection - String concatenation in query" \
    '(SELECT|INSERT|UPDATE|DELETE).*\.\s*\$' "CRITICAL" "*.php"

# XSS
scan_pattern "XSS - Unescaped output" \
    'echo\s+\$_(GET|POST|REQUEST|COOKIE)' "CRITICAL" "*.php"

scan_pattern "XSS - innerHTML with variable" \
    'innerHTML\s*=.*\$|innerHTML\s*=.*\+' "WARNING" "*.js"

# Command Injection
scan_pattern "Command Injection - Shell execution with variable" \
    '(exec|shell_exec|system|passthru|popen)\s*\([^)]*\$' "CRITICAL" "*.php"

scan_pattern "Command Injection - Backtick execution" \
    '`[^`]*\$[^`]*`' "CRITICAL" "*.php"

# Path Traversal / LFI
scan_pattern "Path Traversal - File ops with user input" \
    '(file_get_contents|include|require|fopen)\s*\([^)]*\$_(GET|POST|REQUEST)' "CRITICAL" "*.php"

# Hardcoded Secrets
scan_pattern "Hardcoded Secrets - Password in code" \
    '(password|passwd|secret|api_key|apikey)\s*=\s*["\x27][^"\x27]{8,}' "WARNING" "*.php"

scan_pattern "Hardcoded Secrets - AWS/API keys" \
    '(AKIA[0-9A-Z]{16}|sk_live_|sk_test_)' "CRITICAL" "*"

# SSRF
scan_pattern "SSRF - URL from user input" \
    '(curl_exec|file_get_contents|fopen)\s*\([^)]*\$_(GET|POST|REQUEST)' "CRITICAL" "*.php"

# Insecure Deserialization
scan_pattern "Insecure Deserialization - unserialize user input" \
    'unserialize\s*\([^)]*\$_(GET|POST|REQUEST|COOKIE)' "CRITICAL" "*.php"

# XXE
scan_pattern "XXE - XML parsing without protection" \
    'simplexml_load_string\s*\([^)]*\$|DOMDocument.*loadXML' "WARNING" "*.php"

# CSRF (missing tokens)
scan_pattern "CSRF - Form without token" \
    '<form[^>]*method=["\x27]post["\x27][^>]*>(?!.*csrf|.*token)' "WARNING" "*.php"

# Eval
scan_pattern "Code Injection - eval() usage" \
    'eval\s*\(' "WARNING" "*.php"

scan_pattern "Code Injection - JS eval" \
    'eval\s*\(' "WARNING" "*.js"

# Debug/Dev leftovers
scan_pattern "Debug - var_dump/print_r" \
    '(var_dump|print_r|debug_print_backtrace)\s*\(' "WARNING" "*.php"

scan_pattern "Debug - console.log" \
    'console\.(log|debug|trace)\(' "WARNING" "*.js"

# Dependency Audit
echo "────────────────────────────────────────────"
echo "📦 Dependency Vulnerabilities"
echo ""

if [ -f "$SCAN_PATH/composer.json" ]; then
    if command -v composer &> /dev/null; then
        composer audit --working-dir="$SCAN_PATH" 2>/dev/null || log "${YELLOW}[WARNING] Composer audit found issues${NC}"
    else
        log "${YELLOW}[SKIP] composer not available${NC}"
    fi
fi

if [ -f "$SCAN_PATH/package.json" ]; then
    if command -v npm &> /dev/null; then
        cd "$SCAN_PATH" && npm audit --audit-level=high 2>/dev/null || log "${YELLOW}[WARNING] npm audit found issues${NC}"
        cd - > /dev/null
    else
        log "${YELLOW}[SKIP] npm not available${NC}"
    fi
fi

# Summary
echo ""
echo "════════════════════════════════════════════"
if [ $CRITICAL -gt 0 ]; then
    echo -e "${RED}❌ FAILED: $CRITICAL critical, $WARNINGS warnings${NC}"
    echo "$OUTPUT" > "$VAR_DIR/security_scan_last"
    exit 2
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS: $WARNINGS issues found${NC}"
    echo "$OUTPUT" > "$VAR_DIR/security_scan_last"
    [ "$STRICT" = "--strict" ] && exit 1
    exit 0
else
    echo -e "${GREEN}✅ PASSED: No issues found${NC}"
    exit 0
fi
