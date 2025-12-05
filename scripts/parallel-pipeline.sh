#!/bin/bash
# parallel-pipeline.sh - High-quality code generation with parallel FREE models
#
# Flow:
#   1. Parallel reasoning (codex + gemini) → merged analysis
#   2. Parallel generation (codex + gemini) → two solutions
#   3. Cross-verification (each reviews the other)
#   4. Best solution selection
#
# All heavy lifting done by FREE models (codex/gemini)
# OpenRouter only for quick checks when needed
#
# Usage:
#   parallel-pipeline.sh "task description" [context_var]
#   parallel-pipeline.sh "add password reset" ctx_last

set -e

SCRIPTS_DIR="$HOME/.claude/scripts"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TASK="$1"
CONTEXT_VAR="${2:-ctx_last}"

[[ -z "$TASK" ]] && {
    cat << 'HELP'
parallel-pipeline.sh - High-quality code generation

Usage: parallel-pipeline.sh "task" [context_var]

Flow:
  1. Parallel reasoning (codex + gemini)
  2. Parallel generation (codex + gemini)
  3. Cross-verification
  4. Best solution selection

All using FREE models (your subscriptions)

Examples:
  parallel-pipeline.sh "add password reset endpoint"
  parallel-pipeline.sh "fix authentication bug" ctx_last
HELP
    exit 0
}

# Check if context exists
CONTEXT_FILE="$VAR_DIR/${CONTEXT_VAR}.txt"
HAS_CONTEXT=false
if [[ -f "$CONTEXT_FILE" ]]; then
    HAS_CONTEXT=true
    CONTEXT_REF="@$CONTEXT_FILE"
    echo -e "${BLUE}📋 Using context from \$${CONTEXT_VAR}${NC}" >&2
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "${CYAN}  PARALLEL PIPELINE: $TASK${NC}" >&2
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: PARALLEL REASONING (FREE)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 1: Parallel Reasoning${NC}" >&2

REASONING_PROMPT_CODEX="You are a SOFTWARE ARCHITECT. Analyze this task and identify:
1. Key components needed
2. Design patterns to use
3. Integration points with existing code
4. Potential edge cases

Task: $TASK"

REASONING_PROMPT_GEMINI="You are a SECURITY & QUALITY EXPERT. Analyze this task and identify:
1. Security considerations
2. Input validation needed
3. Error handling requirements
4. Edge cases and failure modes

Task: $TASK"

if $HAS_CONTEXT; then
    REASONING_PROMPT_CODEX="$REASONING_PROMPT_CODEX

Context:
$CONTEXT_REF"
    REASONING_PROMPT_GEMINI="$REASONING_PROMPT_GEMINI

Context:
$CONTEXT_REF"
fi

# Run in parallel
echo -e "  ${BLUE}├─ Codex: Architecture analysis...${NC}" >&2
codex "$REASONING_PROMPT_CODEX" > "$VAR_DIR/reason_codex.txt" 2>/dev/null &
PID_CODEX=$!

echo -e "  ${BLUE}├─ Gemini: Security analysis...${NC}" >&2
gemini "$REASONING_PROMPT_GEMINI" > "$VAR_DIR/reason_gemini.txt" 2>/dev/null &
PID_GEMINI=$!

wait $PID_CODEX $PID_GEMINI
echo -e "  ${GREEN}└─ ✓ Reasoning complete${NC}" >&2

# Merge analyses
MERGED_SPEC="# Implementation Specification

## Architecture (from Codex)
$(cat "$VAR_DIR/reason_codex.txt")

## Security & Quality (from Gemini)
$(cat "$VAR_DIR/reason_gemini.txt")

## Task
$TASK"

echo "$MERGED_SPEC" > "$VAR_DIR/merged_spec.txt"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: PARALLEL GENERATION (FREE)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 2: Parallel Generation${NC}" >&2

GEN_PROMPT="Based on this specification, implement the solution.
Follow existing code patterns and include proper error handling.

$MERGED_SPEC"

if $HAS_CONTEXT; then
    GEN_PROMPT="$GEN_PROMPT

Existing code context:
$CONTEXT_REF"
fi

# Run in parallel
echo -e "  ${BLUE}├─ Codex: Generating solution A...${NC}" >&2
codex "$GEN_PROMPT" > "$VAR_DIR/impl_codex.txt" 2>/dev/null &
PID_CODEX=$!

echo -e "  ${BLUE}├─ Gemini: Generating solution B...${NC}" >&2
gemini "$GEN_PROMPT" > "$VAR_DIR/impl_gemini.txt" 2>/dev/null &
PID_GEMINI=$!

wait $PID_CODEX $PID_GEMINI
echo -e "  ${GREEN}└─ ✓ Generation complete${NC}" >&2

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: CROSS-VERIFICATION (FREE)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 3: Cross-Verification${NC}" >&2

REVIEW_PROMPT_A="Review this code for bugs, security issues, and edge cases.
List any issues found or respond 'LGTM' if none.

Code to review:
$(cat "$VAR_DIR/impl_codex.txt")"

REVIEW_PROMPT_B="Review this code for bugs, security issues, and edge cases.
List any issues found or respond 'LGTM' if none.

Code to review:
$(cat "$VAR_DIR/impl_gemini.txt")"

# Cross-review: Gemini reviews Codex, Codex reviews Gemini
echo -e "  ${BLUE}├─ Gemini reviewing Codex solution...${NC}" >&2
gemini "$REVIEW_PROMPT_A" > "$VAR_DIR/review_of_codex.txt" 2>/dev/null &
PID_REVIEW_A=$!

echo -e "  ${BLUE}├─ Codex reviewing Gemini solution...${NC}" >&2
codex "$REVIEW_PROMPT_B" > "$VAR_DIR/review_of_gemini.txt" 2>/dev/null &
PID_REVIEW_B=$!

wait $PID_REVIEW_A $PID_REVIEW_B
echo -e "  ${GREEN}└─ ✓ Verification complete${NC}" >&2

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: SELECTION (FREE)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${GREEN}▶ PHASE 4: Solution Selection${NC}" >&2

REVIEW_A=$(cat "$VAR_DIR/review_of_codex.txt")
REVIEW_B=$(cat "$VAR_DIR/review_of_gemini.txt")

# Check if either has issues
CODEX_LGTM=false
GEMINI_LGTM=false
[[ "$REVIEW_A" == *"LGTM"* || "$REVIEW_A" == *"no issues"* ]] && CODEX_LGTM=true
[[ "$REVIEW_B" == *"LGTM"* || "$REVIEW_B" == *"no issues"* ]] && GEMINI_LGTM=true

if $CODEX_LGTM && ! $GEMINI_LGTM; then
    echo -e "  ${GREEN}└─ Selected: Codex solution (Gemini had issues)${NC}" >&2
    BEST_SOLUTION=$(cat "$VAR_DIR/impl_codex.txt")
    SELECTION="codex"
elif $GEMINI_LGTM && ! $CODEX_LGTM; then
    echo -e "  ${GREEN}└─ Selected: Gemini solution (Codex had issues)${NC}" >&2
    BEST_SOLUTION=$(cat "$VAR_DIR/impl_gemini.txt")
    SELECTION="gemini"
elif $CODEX_LGTM && $GEMINI_LGTM; then
    # Both good - use Gemini to pick
    echo -e "  ${BLUE}├─ Both solutions LGTM, selecting best...${NC}" >&2
    SELECT_PROMPT="Compare these two solutions and pick the better one.
Respond with ONLY 'A' or 'B'.

Solution A (Codex):
$(cat "$VAR_DIR/impl_codex.txt")

Solution B (Gemini):
$(cat "$VAR_DIR/impl_gemini.txt")"

    PICK=$(gemini "$SELECT_PROMPT" 2>/dev/null | head -1)
    if [[ "$PICK" == *"A"* ]]; then
        BEST_SOLUTION=$(cat "$VAR_DIR/impl_codex.txt")
        SELECTION="codex"
    else
        BEST_SOLUTION=$(cat "$VAR_DIR/impl_gemini.txt")
        SELECTION="gemini"
    fi
    echo -e "  ${GREEN}└─ Selected: ${SELECTION^} solution${NC}" >&2
else
    # Both have issues - merge best parts
    echo -e "  ${YELLOW}├─ Both have issues, merging best parts...${NC}" >&2
    MERGE_PROMPT="Both solutions have issues. Create a merged solution taking the best parts of each.

Solution A issues: $REVIEW_A
Solution A code:
$(cat "$VAR_DIR/impl_codex.txt")

Solution B issues: $REVIEW_B
Solution B code:
$(cat "$VAR_DIR/impl_gemini.txt")"

    BEST_SOLUTION=$(codex "$MERGE_PROMPT" 2>/dev/null)
    SELECTION="merged"
    echo -e "  ${GREEN}└─ Created merged solution${NC}" >&2
fi

# Save final result
echo "$BEST_SOLUTION" > "$VAR_DIR/pipeline_result.txt"
"$SCRIPTS_DIR/var.sh" save "pipeline_result" - "$TASK" < "$VAR_DIR/pipeline_result.txt" >/dev/null

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "${GREEN}✓ PIPELINE COMPLETE${NC}" >&2
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "  Selection: ${SELECTION}" >&2
echo -e "  Result: \$pipeline_result" >&2
echo -e "  Cost: \$0.00 (all FREE models)" >&2
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2

# Output the result
echo "$BEST_SOLUTION"
