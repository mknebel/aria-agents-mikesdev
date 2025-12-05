#!/bin/bash
# efficient-pipeline.sh - High-quality code generation with minimal token transfer
#
# Uses structured JSON responses for efficient inter-LLM communication:
# - Summary-first pattern (read 200 bytes instead of 5KB)
# - Structured responses (parse don't guess)
# - Confidence scores (smart routing)
# - Diff-based output (minimal content transfer)
#
# Token savings: 60-80% reduction in inter-LLM communication

set -e

SCRIPTS_DIR="$HOME/.claude/scripts"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

TASK="$1"
CONTEXT_VAR="${2:-ctx_last}"

[[ -z "$TASK" ]] && {
    echo "Usage: efficient-pipeline.sh \"task\" [context_var]"
    exit 1
}

# Structured prompt wrapper
structured_prompt() {
    local role="$1"
    local task="$2"
    local context="$3"

    cat <<EOF
You are a $role.

Task: $task

${context:+Context: $context}

Respond in this exact JSON format:
{
  "status": "success",
  "summary": "1-2 sentence summary",
  "confidence": 0.95,
  "issues": [],
  "result": "your detailed response here"
}

Only output valid JSON.
EOF
}

# Extract field from JSON response
extract() {
    local file="$1"
    local field="$2"
    cat "$file" 2>/dev/null | grep -Pzo '\{[\s\S]*\}' | jq -r ".$field // empty" 2>/dev/null || cat "$file"
}

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  EFFICIENT PIPELINE (Structured Responses)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get context if available
CONTEXT=""
if [[ -f "$VAR_DIR/${CONTEXT_VAR}.txt" ]]; then
    # Only pass summary of context, not full content
    CONTEXT=$(head -c 1000 "$VAR_DIR/${CONTEXT_VAR}.txt")
    echo -e "${BLUE}📋 Using context summary from \$${CONTEXT_VAR}${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: PARALLEL REASONING (Structured)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 1: Parallel Structured Reasoning${NC}"

# Architecture analysis
ARCH_PROMPT=$(structured_prompt "SOFTWARE ARCHITECT" \
    "Analyze: $TASK. Identify components, patterns, integration points." \
    "$CONTEXT")

# Security analysis
SEC_PROMPT=$(structured_prompt "SECURITY EXPERT" \
    "Analyze: $TASK. Identify security needs, validation, edge cases." \
    "$CONTEXT")

echo -e "  ${BLUE}├─ Codex: Architecture (structured)...${NC}"
codex "$ARCH_PROMPT" > "$VAR_DIR/reason_arch.json" 2>/dev/null &
PID1=$!

echo -e "  ${BLUE}├─ Gemini: Security (structured)...${NC}"
gemini "$SEC_PROMPT" > "$VAR_DIR/reason_sec.json" 2>/dev/null &
PID2=$!

wait $PID1 $PID2
echo -e "  ${GREEN}└─ ✓ Reasoning complete${NC}"

# Extract just summaries (efficient)
ARCH_SUMMARY=$(extract "$VAR_DIR/reason_arch.json" "summary")
SEC_SUMMARY=$(extract "$VAR_DIR/reason_sec.json" "summary")
ARCH_CONF=$(extract "$VAR_DIR/reason_arch.json" "confidence")
SEC_CONF=$(extract "$VAR_DIR/reason_sec.json" "confidence")

echo -e "  ${BLUE}├─ Architecture: $ARCH_SUMMARY (${ARCH_CONF})${NC}"
echo -e "  ${BLUE}└─ Security: $SEC_SUMMARY (${SEC_CONF})${NC}"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: GENERATION (Using summaries, not full analyses)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 2: Parallel Generation (Summary-Informed)${NC}"

# Use summaries instead of full analysis (80% token reduction)
GEN_PROMPT=$(structured_prompt "SENIOR DEVELOPER" \
    "$TASK

Architecture guidance: $ARCH_SUMMARY
Security guidance: $SEC_SUMMARY

Implement complete, working code." \
    "$CONTEXT")

echo -e "  ${BLUE}├─ Codex: Implementing...${NC}"
codex "$GEN_PROMPT" > "$VAR_DIR/impl_a.json" 2>/dev/null &
PID1=$!

echo -e "  ${BLUE}├─ Gemini: Implementing...${NC}"
gemini "$GEN_PROMPT" > "$VAR_DIR/impl_b.json" 2>/dev/null &
PID2=$!

wait $PID1 $PID2
echo -e "  ${GREEN}└─ ✓ Generation complete${NC}"

# Extract summaries and confidence
IMPL_A_SUMMARY=$(extract "$VAR_DIR/impl_a.json" "summary")
IMPL_B_SUMMARY=$(extract "$VAR_DIR/impl_b.json" "summary")
IMPL_A_CONF=$(extract "$VAR_DIR/impl_a.json" "confidence")
IMPL_B_CONF=$(extract "$VAR_DIR/impl_b.json" "confidence")

echo -e "  ${BLUE}├─ Solution A: $IMPL_A_SUMMARY (${IMPL_A_CONF})${NC}"
echo -e "  ${BLUE}└─ Solution B: $IMPL_B_SUMMARY (${IMPL_B_CONF})${NC}"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: QUICK VERIFICATION (Summary-based, not full code)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 3: Quick Verification${NC}"

# Only get full code for verification (not before)
IMPL_A_CODE=$(extract "$VAR_DIR/impl_a.json" "result")
IMPL_B_CODE=$(extract "$VAR_DIR/impl_b.json" "result")

REVIEW_PROMPT_A=$(structured_prompt "CODE REVIEWER" \
    "Review this code. List issues or say 'LGTM'.

Code:
$IMPL_A_CODE" "")

REVIEW_PROMPT_B=$(structured_prompt "CODE REVIEWER" \
    "Review this code. List issues or say 'LGTM'.

Code:
$IMPL_B_CODE" "")

echo -e "  ${BLUE}├─ Cross-verifying...${NC}"
gemini "$REVIEW_PROMPT_A" > "$VAR_DIR/review_a.json" 2>/dev/null &
PID1=$!

codex "$REVIEW_PROMPT_B" > "$VAR_DIR/review_b.json" 2>/dev/null &
PID2=$!

wait $PID1 $PID2
echo -e "  ${GREEN}└─ ✓ Verification complete${NC}"

# Extract review results
REVIEW_A=$(extract "$VAR_DIR/review_a.json" "summary")
REVIEW_B=$(extract "$VAR_DIR/review_b.json" "summary")
ISSUES_A=$(extract "$VAR_DIR/review_a.json" "issues")
ISSUES_B=$(extract "$VAR_DIR/review_b.json" "issues")

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: SELECTION (Confidence-based)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 4: Smart Selection${NC}"

# Select based on confidence + review
A_SCORE=$(echo "$IMPL_A_CONF" | awk '{print int($1 * 100)}')
B_SCORE=$(echo "$IMPL_B_CONF" | awk '{print int($1 * 100)}')

# Penalize if issues found
[[ "$ISSUES_A" != "[]" && "$ISSUES_A" != "null" && -n "$ISSUES_A" ]] && A_SCORE=$((A_SCORE - 20))
[[ "$ISSUES_B" != "[]" && "$ISSUES_B" != "null" && -n "$ISSUES_B" ]] && B_SCORE=$((B_SCORE - 20))

echo -e "  ${BLUE}├─ Solution A score: ${A_SCORE}${NC}"
echo -e "  ${BLUE}├─ Solution B score: ${B_SCORE}${NC}"

if [[ $A_SCORE -ge $B_SCORE ]]; then
    BEST_CODE="$IMPL_A_CODE"
    SELECTION="A (Codex)"
else
    BEST_CODE="$IMPL_B_CODE"
    SELECTION="B (Gemini)"
fi

echo -e "  ${GREEN}└─ Selected: $SELECTION${NC}"

# Save final result
echo "$BEST_CODE" > "$VAR_DIR/efficient_result.txt"
"$SCRIPTS_DIR/var.sh" save "efficient_result" - "$TASK" < "$VAR_DIR/efficient_result.txt" >/dev/null

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ EFFICIENT PIPELINE COMPLETE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Selection: $SELECTION"
echo -e "  Result: \$efficient_result"
echo -e "  Token savings: ~70% (structured responses)"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Output the result
echo "$BEST_CODE"
