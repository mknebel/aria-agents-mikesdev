#!/bin/bash
# ARIA Iteration Breaker - Integration Test
# Simpler tests that don't require sourcing in subprocesses

# Source dependencies
source ~/.claude/scripts/aria-iteration-breaker.sh 2>/dev/null || {
    echo "Error: aria-iteration-breaker.sh not found" >&2
    exit 2
}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ARIA Iteration Breaker - Integration Test${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Test 1: Help command
echo -e "${YELLOW}Test 1: Help command${NC}"
if aria-iteration-breaker.sh help 2>&1 | grep -q "Usage:"; then
    echo -e "${GREEN}✓ PASS${NC}: Help works"
else
    echo -e "✗ FAIL: Help command"
fi

# Test 2: Status command
echo ""
echo -e "${YELLOW}Test 2: Status command${NC}"
if aria-iteration-breaker.sh status | grep -q "Iteration Breaker"; then
    echo -e "${GREEN}✓ PASS${NC}: Status works"
else
    echo -e "✗ FAIL: Status command"
fi

# Test 3: Error similarity function
echo ""
echo -e "${YELLOW}Test 3: Error similarity matching${NC}"
if _error_similarity "TypeError: Cannot read" "TypeError: Cannot read"; then
    echo -e "${GREEN}✓ PASS${NC}: Exact match works"
else
    echo -e "✗ FAIL: Exact match"
fi

if ! _error_similarity "TypeError: cannot read property" "SyntaxError: unexpected token"; then
    echo -e "${GREEN}✓ PASS${NC}: Different error types don't match"
else
    echo -e "✗ FAIL: Different error type detection"
fi

# Test 4: Create mock task and test loop detection
echo ""
echo -e "${YELLOW}Test 4: Loop detection (repeated error)${NC}"

task_id="test_$(date +%s)_loop"
state_file=$(_aria_task_file "$task_id")
mkdir -p "$(dirname "$state_file")"

cat > "$state_file" << 'EOF'
{
  "task_id": "test_loop",
  "task_desc": "Test task",
  "attempt_count": 3,
  "model_tier": 2,
  "created_at": "1234567890",
  "failures": [
    {"attempt": 1, "error": "TypeError: Cannot read property 'map'", "model": "gpt-5.1", "timestamp": "1"},
    {"attempt": 2, "error": "TypeError: Cannot read property 'map'", "model": "gpt-5.1", "timestamp": "2"},
    {"attempt": 3, "error": "TypeError: Cannot read property 'map'", "model": "gpt-5.1", "timestamp": "3"}
  ],
  "escalation_log": [],
  "quality_gate_results": []
}
EOF

if aria_loop_check "$task_id"; then
    echo -e "${GREEN}✓ PASS${NC}: Loop detected correctly"
else
    echo -e "✗ FAIL: Loop not detected"
fi

# Test 5: Analysis function
echo ""
echo -e "${YELLOW}Test 5: Loop analysis${NC}"
analysis=$(aria_loop_analyze "$task_id" 2>/dev/null)

if echo "$analysis" | jq -e '.pattern_type' > /dev/null 2>&1; then
    pattern=$(echo "$analysis" | jq -r '.pattern_type')
    echo -e "${GREEN}✓ PASS${NC}: Analysis generated (pattern: $pattern)"
else
    echo -e "✗ FAIL: Analysis generation"
fi

# Test 6: Force escalation
echo ""
echo -e "${YELLOW}Test 6: Force escalation${NC}"
new_tier=$(aria_force_escalate "$task_id" "Test escalation" 2>/dev/null)
if [[ "$new_tier" == "4" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: Escalated from tier 2 to tier 4"
else
    echo -e "✗ FAIL: Escalation (got tier $new_tier)"
fi

# Test 7: Circuit break
echo ""
echo -e "${YELLOW}Test 7: Circuit breaking${NC}"
summary_file=$(aria_circuit_break "$task_id" "Test circuit break" 2>/dev/null)
if [[ -f "$summary_file" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: Summary file created"
    if grep -q "ARIA ITERATION BREAKER" "$summary_file"; then
        echo -e "${GREEN}✓ PASS${NC}: Summary has proper header"
    fi
else
    echo -e "✗ FAIL: Summary file not created"
fi

# Test 8: Blocked tasks registry
echo ""
echo -e "${YELLOW}Test 8: Blocked tasks registry${NC}"
if [[ -f "$BLOCKED_TASKS_STATE" ]]; then
    count=$(jq '.blocked_tasks | length' "$BLOCKED_TASKS_STATE" 2>/dev/null)
    echo -e "${GREEN}✓ PASS${NC}: Blocked tasks registry updated ($count blocked)"
else
    echo -e "✗ FAIL: Blocked tasks registry"
fi

# Test 9: Cleanup
echo ""
echo -e "${YELLOW}Test 9: Task cleanup${NC}"
aria_iteration_cleanup "$task_id" 2>/dev/null
if aria_loop_check "$task_id" 2>/dev/null; then
    echo -e "✗ FAIL: Task not cleaned up"
else
    echo -e "${GREEN}✓ PASS${NC}: Task cleaned up successfully"
fi

# Test 10: No loop detection (single failure)
echo ""
echo -e "${YELLOW}Test 10: No loop detection${NC}"
task_id2="test_$(date +%s)_noloop"
state_file2=$(_aria_task_file "$task_id2")
mkdir -p "$(dirname "$state_file2")"

cat > "$state_file2" << 'EOF'
{
  "task_id": "test_noloop",
  "task_desc": "Test task",
  "attempt_count": 1,
  "model_tier": 2,
  "created_at": "1234567890",
  "failures": [
    {"attempt": 1, "error": "Some error", "model": "gpt-5.1", "timestamp": "1"}
  ],
  "escalation_log": [],
  "quality_gate_results": []
}
EOF

if ! aria_loop_check "$task_id2"; then
    echo -e "${GREEN}✓ PASS${NC}: Single failure not detected as loop"
else
    echo -e "✗ FAIL: False positive loop detection"
fi

# Cleanup test files
rm -f "$state_file2" 2>/dev/null

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Integration test complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
