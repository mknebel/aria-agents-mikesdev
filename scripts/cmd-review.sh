#!/bin/bash
# cmd-review.sh - Pre-commit review checks
echo "=== Code Review Checklist ==="

CHANGED=$(git diff --name-only HEAD 2>/dev/null)
STAGED=$(git diff --cached --name-only 2>/dev/null)
[[ -z "$CHANGED" && -z "$STAGED" ]] && { echo "No changes to review."; exit 0; }

echo "Files:"
echo "$CHANGED" "$STAGED" | sort -u | head -20
echo ""

echo "=== Automated Checks ==="
echo "Debug statements:"
git diff HEAD --name-only | xargs grep -l -E '(console\.log|var_dump|print_r|dd\(|dump\()' 2>/dev/null || echo "  None"

echo -e "\nTODOs:"
git diff HEAD --name-only | xargs grep -n "TODO\|FIXME" 2>/dev/null || echo "  None"

echo -e "\nSecrets:"
git diff HEAD | grep -E "(password|secret|api_key|token).*[=:].*['\"][^'\"]{8,}" -i 2>/dev/null || echo "  None"

echo -e "\n=== Manual Checklist ==="
echo "Security: secrets, SQL injection, XSS, logs"
echo "Quality: TODOs, debug code, function size, naming"
echo "Logic: edge cases, error handling, transactions"
echo "Tests: new tests, existing pass, edge cases"
