#!/bin/bash
# ARIA Iteration Breaker - Test Suite
# Comprehensive tests for loop detection and circuit breaker functionality

# Note: Don't use 'set -e' because tests intentionally fail
set -uo pipefail

# Source dependencies
source ~/.claude/scripts/aria-iteration-breaker.sh 2>/dev/null || {
    echo "Error: aria-iteration-breaker.sh not found" >&2
    exit 2
}

# =============================================================================
# TEST CONFIGURATION
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Temp directory for test data
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# =============================================================================
# TEST UTILITIES
# =============================================================================

_test_header() {
    echo ""
    echo -e "${CYAN}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════${NC}"
}

_test_case() {
    ((TESTS_TOTAL++))
    echo -e "\n${YELLOW}Test $TESTS_TOTAL: $1${NC}"
}

_assert_success() {
    local cmd="$1"
    local msg="${2:-Command should succeed}"

    if bash -c "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $msg"
        ((TESTS_FAILED++))
        return 1
    fi
}

_assert_failure() {
    local cmd="$1"
    local msg="${2:-Command should fail}"

    if ! bash -c "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $msg"
        ((TESTS_FAILED++))
        return 1
    fi
}

_assert_equal() {
    local actual="$1"
    local expected="$2"
    local msg="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $msg"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

_assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $msg"
        echo "  Expected to contain: '$needle'"
        echo "  Actual: '$haystack'"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Create mock task state for testing
_create_mock_task() {
    local task_id="$1"
    local desc="${2:-Test task}"
    local failures="${3:-[]}"

    local state_file=$(_aria_task_file "$task_id")
    mkdir -p "$(dirname "$state_file")"

    cat > "$state_file" << EOF
{
  "task_id": "$task_id",
  "task_desc": "$desc",
  "attempt_count": $(echo "$failures" | jq 'length'),
  "model_tier": 2,
  "created_at": "$(date +%s)",
  "failures": $failures,
  "escalation_log": [],
  "quality_gate_results": []
}
EOF
}

# =============================================================================
# TEST SUITES
# =============================================================================

test_error_similarity() {
    _test_header "Error Similarity Matching"

    _test_case "Exact match should be similar"
    _assert_success \
        "_error_similarity 'TypeError: Cannot read' 'TypeError: Cannot read'" \
        "Exact error strings match"

    _test_case "Different errors should not match"
    _assert_failure \
        "_error_similarity 'TypeError: Cannot read' 'SyntaxError: Unexpected token'" \
        "Different error types don't match"

    _test_case "Same error type should match (partial)"
    _assert_success \
        "_error_similarity 'TypeError: Cannot read property x' 'TypeError: Cannot read property y'" \
        "Same error type prefix matches"

    _test_case "Contained error should match"
    _assert_success \
        "_error_similarity 'TypeError: foo bar' 'TypeError: foo bar baz'" \
        "Contained error matches"
}

test_loop_detection() {
    _test_header "Loop Detection - Same Error"

    # Create task with repeated same error
    local task_id="test_loop_same_001"
    local failures=$(cat << 'EOF'
[
  {"attempt": 1, "error": "TypeError: Cannot read property 'map'", "model": "gpt-5.1", "timestamp": "1"},
  {"attempt": 2, "error": "TypeError: Cannot read property 'map'", "model": "gpt-5.1", "timestamp": "2"},
  {"attempt": 3, "error": "Some other error", "model": "gpt-5.1", "timestamp": "3"}
]
EOF
)
    _create_mock_task "$task_id" "Test loop detection" "$failures"

    _test_case "Should detect same error appearing 2+ times"
    _assert_success \
        "aria_loop_check $task_id" \
        "Loop detected with 2+ same errors"

    _test_header "Loop Detection - Stuck Tier"

    # Create task with multiple attempts but no escalation
    local task_id="test_loop_stuck_002"
    local failures=$(cat << 'EOF'
[
  {"attempt": 1, "error": "Error A", "model": "gpt-5.1", "timestamp": "1"},
  {"attempt": 2, "error": "Error B", "model": "gpt-5.1", "timestamp": "2"},
  {"attempt": 3, "error": "Error C", "model": "gpt-5.1", "timestamp": "3"}
]
EOF
)
    _create_mock_task "$task_id" "Stuck tier test" "$failures"

    _test_case "Should detect stuck tier (3+ attempts, no escalation)"
    _assert_success \
        "aria_loop_check $task_id" \
        "Loop detected with stuck tier"

    _test_header "Loop Detection - No Loop"

    # Create task with single failure
    local task_id="test_no_loop_003"
    local failures=$(cat << 'EOF'
[
  {"attempt": 1, "error": "Error A", "model": "gpt-5.1", "timestamp": "1"}
]
EOF
)
    _create_mock_task "$task_id" "No loop test" "$failures"

    _test_case "Should not detect loop with single failure"
    _assert_failure \
        "aria_loop_check $task_id" \
        "No loop with single failure"
}

test_loop_analysis() {
    _test_header "Loop Analysis"

    local task_id="test_analysis_004"
    local failures=$(cat << 'EOF'
[
  {"attempt": 1, "error": "TypeError: Cannot read", "model": "gpt-5.1", "timestamp": "1"},
  {"attempt": 2, "error": "TypeError: Cannot read", "model": "gpt-5.1", "timestamp": "2"},
  {"attempt": 3, "error": "TypeError: Cannot read", "model": "gpt-5.1", "timestamp": "3"}
]
EOF
)
    _create_mock_task "$task_id" "Analysis test" "$failures"

    _test_case "Should generate valid JSON analysis"
    local analysis=$(aria_loop_analyze "$task_id" 2>/dev/null || echo "{}")
    _assert_contains "$analysis" '"pattern_type"' "Analysis contains pattern_type"

    _test_case "Should identify correct pattern"
    local pattern=$(echo "$analysis" | jq -r '.pattern_type // "unknown"')
    _assert_equal "$pattern" "repeated_error" "Pattern identified as repeated_error"

    _test_case "Should count error occurrences"
    local count=$(echo "$analysis" | jq -r '.repeated_error_count // 0')
    _assert_equal "$count" "3" "Error count is 3"

    _test_case "Should suggest action"
    local action=$(echo "$analysis" | jq -r '.suggested_action // ""')
    _assert_contains "$action" "escalate" "Suggested action mentions escalation"
}

test_force_escalate() {
    _test_header "Force Escalation"

    local task_id="test_escalate_005"
    local failures='[]'
    _create_mock_task "$task_id" "Escalation test" "$failures"

    # Set initial tier to 2
    local state_file=$(_aria_task_file "$task_id")
    jq '.model_tier = 2' "$state_file" > "${state_file}.tmp" 2>/dev/null
    mv "${state_file}.tmp" "$state_file"

    _test_case "Should escalate 2 tiers (from 2 to 4)"
    local new_tier=$(aria_force_escalate "$task_id" "Test escalation")
    _assert_equal "$new_tier" "4" "Escalated from tier 2 to tier 4"

    _test_case "Should cap at tier 7"
    jq '.model_tier = 6' "$state_file" > "${state_file}.tmp" 2>/dev/null
    mv "${state_file}.tmp" "$state_file"
    local result=$(aria_force_escalate "$task_id" "Test cap" 2>/dev/null || echo "CAPPED")
    if [[ "$result" == "7" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Tier capped at 7"
        ((TESTS_PASSED++))
    fi

    _test_case "Should require human intervention at max tier"
    jq '.model_tier = 7' "$state_file" > "${state_file}.tmp" 2>/dev/null
    mv "${state_file}.tmp" "$state_file"
    local result=$(aria_force_escalate "$task_id" "Test max" 2>/dev/null || echo "")
    _assert_equal "$result" "HUMAN_INTERVENTION_REQUIRED" "Human intervention required at max tier"
}

test_circuit_break() {
    _test_header "Circuit Breaking"

    local task_id="test_break_006"
    local failures='[{"attempt": 1, "error": "Test error", "model": "gpt-5.1", "timestamp": "1"}]'
    _create_mock_task "$task_id" "Circuit break test" "$failures"

    _test_case "Should generate summary file"
    local summary_file=$(aria_circuit_break "$task_id" "Test break" 2>/dev/null)
    _assert_success "test -f '$summary_file'" "Summary file created"

    _test_case "Summary should contain task ID"
    if [[ -f "$summary_file" ]]; then
        _assert_contains "$(cat $summary_file)" "$task_id" "Summary contains task ID"
    fi

    _test_case "Summary should contain suggested action"
    if [[ -f "$summary_file" ]]; then
        _assert_contains "$(cat $summary_file)" "SUGGESTED ACTION" "Summary has action section"
    fi
}

test_blocked_tasks_registry() {
    _test_header "Blocked Tasks Registry"

    local task_id="test_blocked_007"
    _create_mock_task "$task_id" "Blocked task test" '[]'

    _test_case "Should add task to blocked registry"
    aria_circuit_break "$task_id" "Test block" > /dev/null 2>&1
    if [[ -f "$BLOCKED_TASKS_STATE" ]]; then
        local count=$(jq '.blocked_tasks | length' "$BLOCKED_TASKS_STATE" 2>/dev/null || echo 0)
        if [[ $count -gt 0 ]]; then
            echo -e "${GREEN}✓ PASS${NC}: Task added to blocked registry"
            ((TESTS_PASSED++))
        fi
    fi

    _test_case "Should cleanup blocked task"
    aria_iteration_cleanup "$task_id" > /dev/null 2>&1
    if [[ -f "$BLOCKED_TASKS_STATE" ]]; then
        local found=$(jq ".blocked_tasks[] | select(.task_id == \"$task_id\") | .task_id" "$BLOCKED_TASKS_STATE" 2>/dev/null)
        if [[ -z "$found" ]]; then
            echo -e "${GREEN}✓ PASS${NC}: Task removed from blocked registry"
            ((TESTS_PASSED++))
        fi
    fi
}

test_cli_interface() {
    _test_header "CLI Interface"

    _test_case "Should show help"
    _assert_success \
        "aria-iteration-breaker.sh help | grep -q 'Usage:'" \
        "Help command works"

    _test_case "Should show status"
    _assert_success \
        "aria-iteration-breaker.sh status" \
        "Status command works"

    _test_case "Should reject missing task_id"
    _assert_failure \
        "aria-iteration-breaker.sh check" \
        "Rejects missing task_id for check"

    _test_case "Should reject invalid command"
    _assert_failure \
        "aria-iteration-breaker.sh invalid_command" \
        "Rejects invalid command"
}

# =============================================================================
# TEST EXECUTION
# =============================================================================

_test_header "ARIA ITERATION BREAKER - TEST SUITE"

test_error_similarity
test_loop_detection
test_loop_analysis
test_force_escalate
test_circuit_break
test_blocked_tasks_registry
test_cli_interface

# =============================================================================
# TEST SUMMARY
# =============================================================================

echo ""
echo -e "${CYAN}═════════════════════════════════════════════════════════════${NC}"
echo "TEST RESULTS"
echo -e "${CYAN}═════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Total Tests:  $TESTS_TOTAL"
echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
