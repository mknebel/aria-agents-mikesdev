#!/bin/bash
# plan-pipeline.sh - Collaborative planning with Gemini + Codex
# Usage: plan-pipeline.sh "task description" [path]
#
# Flow: Gemini (context, 1M tokens) → Codex (plan) → Gemini (review) → Combined output

set -e

TASK="$1"
SEARCH_PATH="${2:-.}"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

if [ -z "$TASK" ]; then
    echo "Usage: plan-pipeline.sh \"task description\" [path]"
    exit 1
fi

echo "═══════════════════════════════════════"
echo "📋 COLLABORATIVE PLAN PIPELINE"
echo "═══════════════════════════════════════"
echo "Task: $TASK"
echo "Path: $SEARCH_PATH"
echo ""

# Step 1: Gemini gathers deep context (FREE - 1M tokens)
echo "▶ Step 1: Deep context gathering (Gemini 1M context)..."

CONTEXT_PROMPT="Analyze codebase for task: $TASK

You have 1M token context - be thorough. Find and document:

1. **Relevant Files** (with line numbers for key sections)
2. **Key Functions/Classes** - signatures and purposes
3. **Data Flow** - how data moves through the system
4. **Dependencies** - internal and external
5. **Patterns** - existing conventions to follow
6. **Potential Issues** - gotchas, edge cases
7. **Test Coverage** - existing tests that may need updates

Output structured summary optimized for implementation planning."

if command -v gemini &> /dev/null; then
    cd "$SEARCH_PATH"
    CONTEXT=$(gemini "$CONTEXT_PROMPT" @. 2>/dev/null || echo "Gemini unavailable")
    cd - > /dev/null
else
    CONTEXT="Gemini CLI not available."
fi

echo "$CONTEXT" > "$VAR_DIR/gemini_context"
echo "   Context saved to \$gemini_context"
echo ""

# Step 2: Codex creates implementation plan using Gemini's context
echo "▶ Step 2: Implementation plan (Codex + Gemini context)..."
PLAN_PROMPT="Create detailed implementation plan.

TASK: $TASK

CONTEXT FROM GEMINI (1M token analysis):
$CONTEXT

OUTPUT FORMAT:
## Summary
[1-2 sentences]

## Files to Modify/Create
| File | Action | Changes |
|------|--------|---------|
| exact/path | create/modify/delete | specific changes |

## Implementation Steps
1. [specific step with file:line references]
2. [specific step]
...

## Code Patterns to Follow
[Based on existing codebase patterns from context]

## Tests to Update/Add
[Specific test files and cases]

## Risks & Mitigations
- [risk]: [mitigation]

Be specific. Use exact file paths and function names from context."

if command -v codex &> /dev/null; then
    CODEX_PLAN=$(codex -q "$PLAN_PROMPT" 2>/dev/null || echo "Codex unavailable")
else
    CODEX_PLAN=$(~/.claude/scripts/ai.sh tools "$PLAN_PROMPT" 2>/dev/null || echo "External planning unavailable")
fi

echo "$CODEX_PLAN" > "$VAR_DIR/codex_plan"
echo "   Codex plan saved to \$codex_plan"
echo ""

# Step 3: Gemini reviews and enhances Codex plan
echo "▶ Step 3: Plan review & enhancement (Gemini)..."

REVIEW_PROMPT="Review this implementation plan against the codebase.

TASK: $TASK

CODEX PLAN:
$CODEX_PLAN

Review for:
1. **Completeness** - Any missing files or steps?
2. **Accuracy** - Do file paths and function names exist?
3. **Patterns** - Does it follow existing code conventions?
4. **Edge Cases** - Any missing error handling?
5. **Dependencies** - Any import/require changes needed?

Output:
## Plan Validation
✓ [correct items]
⚠ [items needing adjustment]

## Suggested Additions
[Any missing steps or files]

## Final Recommendation
[APPROVE / NEEDS_ADJUSTMENT with specific fixes]"

if command -v gemini &> /dev/null; then
    cd "$SEARCH_PATH"
    GEMINI_REVIEW=$(gemini "$REVIEW_PROMPT" @. 2>/dev/null || echo "Review skipped")
    cd - > /dev/null
else
    GEMINI_REVIEW="Gemini review skipped."
fi

echo "$GEMINI_REVIEW" > "$VAR_DIR/gemini_review"
echo "   Review saved to \$gemini_review"
echo ""

# Step 4: Combined output for Claude
echo "═══════════════════════════════════════"
echo "📝 COLLABORATIVE PLAN OUTPUT"
echo "═══════════════════════════════════════"

# Create combined plan file
cat > "$VAR_DIR/combined_plan" << COMBINED
# Implementation Plan: $TASK

## Codex Plan
$CODEX_PLAN

---

## Gemini Review
$GEMINI_REVIEW

---

## Variables Available
- \$gemini_context - Deep codebase analysis
- \$codex_plan - Implementation plan
- \$gemini_review - Plan validation
- \$combined_plan - This combined output
COMBINED

echo ""
cat "$VAR_DIR/combined_plan"
echo ""
echo "═══════════════════════════════════════"
echo "⏳ AWAITING CLAUDE REVIEW"
echo "═══════════════════════════════════════"
echo "Variables created:"
echo "  \$gemini_context  - Codebase analysis (1M context)"
echo "  \$codex_plan      - Implementation plan"
echo "  \$gemini_review   - Plan validation"
echo "  \$combined_plan   - Combined output"
echo ""
echo "Actions:"
echo "  APPROVE  → /apply (aria-coder implements)"
echo "  MODIFY   → edit \$codex_plan, then /apply"
echo "  REJECT   → /thinking (Opus deep reasoning)"
echo ""
