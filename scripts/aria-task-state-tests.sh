#!/bin/bash
# Test suite for aria-task-state.sh

source /home/mike/.claude/scripts/aria-task-state.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEST_PASS=0
TEST_FAIL=0

# Test helper
assert_equal() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TEST_PASS++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((TEST_FAIL++))
    fi
}

# Cleanup before tests
rm -f /tmp/aria-task-*.json 2>/dev/null

echo -e "\n${YELLOW}=== ARIA Task State Tests ===${NC}\n"

# Test 1: Initialization
echo -e "${YELLOW}Test Group: Initialization${NC}"
task_id=$(aria_task_init "Sample task for testing")
[[ -n "$task_id" ]] && assert_equal "1" "1" "task_init returns task_id" || assert_equal "task_id" "empty" "task_init returns task_id"

attempt=$(aria_task_get "$task_id" "attempt_count")
assert_equal "0" "$attempt" "Initial attempt_count is 0"

tier=$(aria_task_get "$task_id" "model_tier")
assert_equal "1" "$tier" "Initial model_tier is 1"

# Test 2: Increment attempt
echo -e "\n${YELLOW}Test Group: Attempt Tracking${NC}"
count=$(aria_task_increment_attempt "$task_id")
assert_equal "1" "$count" "First increment returns 1"

count=$(aria_task_increment_attempt "$task_id")
assert_equal "2" "$count" "Second increment returns 2"

# Test 3: Failures
echo -e "\n${YELLOW}Test Group: Failure Recording${NC}"
aria_task_record_failure "$task_id" "Error message 1"
aria_task_record_failure "$task_id" "Error message 2"
context=$(aria_task_get_failure_context "$task_id")
[[ "$context" =~ "Error message 1" ]] && assert_equal "1" "1" "Failure context contains first error" || assert_equal "1" "0" "Failure context contains first error"
[[ "$context" =~ "Error message 2" ]] && assert_equal "1" "1" "Failure context contains second error" || assert_equal "1" "0" "Failure context contains second error"

# Test 4: Escalation
echo -e "\n${YELLOW}Test Group: Escalation${NC}"
new_tier=$(aria_task_escalate "$task_id" "Escalating to tier 2")
assert_equal "2" "$new_tier" "Escalate tier 1->2"

new_tier=$(aria_task_escalate "$task_id" "Escalating to tier 3")
assert_equal "3" "$new_tier" "Escalate tier 2->3"

# Test 5: Concurrent access
echo -e "\n${YELLOW}Test Group: Concurrent Access${NC}"
task_id2=$(aria_task_init "Concurrent test task")
for i in {1..5}; do
    aria_task_increment_attempt "$task_id2" > /dev/null &
done
wait
final=$(aria_task_get "$task_id2" "attempt_count")
assert_equal "5" "$final" "5 concurrent increments result in count=5"

# Test 6: Set/Get arbitrary fields
echo -e "\n${YELLOW}Test Group: Custom Fields${NC}"
aria_task_set "$task_id" "custom_key" "custom_value"
value=$(aria_task_get "$task_id" "custom_key")
assert_equal "custom_value" "$value" "Custom field set and get"

aria_task_set "$task_id" "numeric_field" 42
value=$(aria_task_get "$task_id" "numeric_field")
assert_equal "42" "$value" "Numeric field set and get"

# Test 7: Cleanup
echo -e "\n${YELLOW}Test Group: Cleanup${NC}"
aria_task_cleanup "$task_id"
aria_task_cleanup "$task_id2"
count=$(ls /tmp/aria-task-*.json 2>/dev/null | wc -l)
assert_equal "0" "$count" "Cleanup removes all task state files"

# Summary
echo -e "\n${YELLOW}=== Test Summary ===${NC}"
echo -e "${GREEN}Passed: $TEST_PASS${NC}"
if [[ $TEST_FAIL -gt 0 ]]; then
    echo -e "${RED}Failed: $TEST_FAIL${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
