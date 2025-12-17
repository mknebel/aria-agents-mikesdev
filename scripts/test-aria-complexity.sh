#!/bin/bash
# Test suite for aria-complexity.sh
# Run this to verify functionality

source ~/.claude/scripts/aria-complexity.sh

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

test_case() {
    local name="$1"
    local task="$2"
    local error_file="$3"
    local expected="$4"
    
    ((TESTS_TOTAL++))
    
    if [[ -n "$error_file" ]]; then
        result=$(aria_assess_complexity "$task" "$error_file")
    else
        result=$(aria_assess_complexity "$task")
    fi
    
    if [[ "$result" == "$expected" ]]; then
        echo "✓ [$TESTS_TOTAL] $name"
        ((TESTS_PASSED++))
    else
        echo "✗ [$TESTS_TOTAL] $name (got $result, expected $expected)"
        ((TESTS_FAILED++))
    fi
}

# Setup test error file
TEST_ERROR="/tmp/aria_test_error_$$.log"
echo "Test error" > "$TEST_ERROR"
trap "rm -f $TEST_ERROR" EXIT

echo ""
echo "╔═════════════════════════════════════════════════════════════════╗"
echo "║  ARIA Complexity Assessment - Test Suite                       ║"
echo "╚═════════════════════════════════════════════════════════════════╝"
echo ""

echo "TIER 1 TESTS (Simple - Bug fixes, typos)"
echo "─────────────────────────────────────────────────────────────────"
test_case "Simple typo fix" "Fix typo in README" "" 1
test_case "Bug fix" "Fix bug" "" 1
test_case "Quick patch" "Quick fix in utils.js" "" 1
test_case "Multiple simple keywords" "Fix quick bugs and typos" "" 1
echo ""

echo "TIER 2 TESTS (Standard - Features, moderate complexity)"
echo "─────────────────────────────────────────────────────────────────"
test_case "Standard feature" "Implement new user profile page" "" 2
test_case "Authentication" "Add password validation system" "" 2
test_case "Error with fix keyword" "Fix bug in auth" "$TEST_ERROR" 1
test_case "Mixed increase/decrease" "Refactor simple utility" "" 2
echo ""

echo "TIER 3 TESTS (Complex - Architecture, multi-system)"
echo "─────────────────────────────────────────────────────────────────"
test_case "Refactor keyword" "Refactor authentication system" "" 3
test_case "Rewrite keyword" "Rewrite database layer" "" 3
test_case "Multi-system integration" "Integrate API with frontend database" "" 3
test_case "Architecture changes" "Redesign database migration architecture" "" 3
test_case "Multiple files" "Update src/app.js src/utils.js src/api.js tests/app.test.js" "" 3
echo ""

echo "EDGE CASES"
echo "─────────────────────────────────────────────────────────────────"
test_case "Empty input (should default to 2)" "" "" 2
test_case "Case insensitivity (FIX BUG)" "FIX BUG" "" 1
test_case "Case insensitivity (Refactor)" "Refactor system" "" 3
echo ""

echo "RETURN CODE TESTS"
echo "─────────────────────────────────────────────────────────────────"
aria_assess_complexity "Fix bug" > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "✓ Valid input returns 0"
    ((TESTS_PASSED++))
else
    echo "✗ Valid input should return 0"
    ((TESTS_FAILED++))
fi
((TESTS_TOTAL++))

aria_assess_complexity "" > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
    echo "✓ Invalid input returns 1"
    ((TESTS_PASSED++))
else
    echo "✗ Invalid input should return 1"
    ((TESTS_FAILED++))
fi
((TESTS_TOTAL++))
echo ""

echo "╔═════════════════════════════════════════════════════════════════╗"
echo "║  Test Results                                                  ║"
echo "╠═════════════════════════════════════════════════════════════════╣"
printf "║  Total:  %-2d    Passed: %-2d (%3d%%)    Failed: %-2d\n" "$TESTS_TOTAL" "$TESTS_PASSED" "$((TESTS_PASSED * 100 / TESTS_TOTAL))" "$TESTS_FAILED"
echo "╚═════════════════════════════════════════════════════════════════╝"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "All tests passed! aria-complexity.sh is working correctly."
    exit 0
else
    echo "Some tests failed. Check the output above."
    exit 1
fi
