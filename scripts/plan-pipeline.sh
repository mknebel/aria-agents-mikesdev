#!/bin/bash
# plan-pipeline.sh - External-first planning pipeline
# Usage: plan-pipeline.sh "task description" [path]
#
# Flow: Gemini (context) → Codex (plan) → Output for Claude review

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
echo "📋 PLAN PIPELINE"
echo "═══════════════════════════════════════"
echo "Task: $TASK"
echo "Path: $SEARCH_PATH"
echo ""

# Step 1: Gemini gathers context (FREE - 1M tokens)
echo "▶ Step 1: Gathering context (Gemini)..."

# Check if recent context exists (< 10 min)
if find "$VAR_DIR/gemini_context" -mmin -10 2>/dev/null | grep -q .; then
    echo "   Using cached context (< 10 min old)"
    CONTEXT=$(cat "$VAR_DIR/gemini_context")
else
    CONTEXT_PROMPT="Analyze codebase for task: $TASK

Find and summarize:
1. Relevant files and their purposes
2. Key functions/classes involved
3. Dependencies and relationships
4. Existing patterns to follow

Output compact summary for implementation planning."

    if command -v gemini &> /dev/null; then
        cd "$SEARCH_PATH"
        CONTEXT=$(gemini "$CONTEXT_PROMPT" @. 2>/dev/null || echo "Gemini unavailable - proceeding without context")
        cd - > /dev/null
    else
        CONTEXT="Gemini CLI not available. Codex will gather context directly."
    fi
fi

echo "$CONTEXT" > "$VAR_DIR/gemini_context"
echo "   Context saved to \$gemini_context"
echo ""

# Step 2: Codex creates plan (FREE - your OpenAI sub)
echo "▶ Step 2: Creating plan (Codex)..."
PLAN_PROMPT="Create implementation plan.

TASK: $TASK

CONTEXT:
$CONTEXT

OUTPUT FORMAT:
## Summary
[1-2 sentences]

## Files
| File | Action | Purpose |
|------|--------|---------|
| path | create/modify | why |

## Steps
1. [specific step]
2. [specific step]

## Risks
- [if any]

Be specific. Reference exact files/functions."

if command -v codex &> /dev/null; then
    PLAN=$(codex -q "$PLAN_PROMPT" 2>/dev/null || echo "Codex unavailable")
else
    # Fallback to ai.sh
    PLAN=$(~/.claude/scripts/ai.sh tools "$PLAN_PROMPT" 2>/dev/null || echo "External planning unavailable")
fi

echo "$PLAN" > "$VAR_DIR/codex_plan"
echo "   Plan saved to \$codex_plan"
echo ""

# Step 3: Output for review
echo "═══════════════════════════════════════"
echo "📝 PLAN FOR REVIEW"
echo "═══════════════════════════════════════"
echo ""
cat "$VAR_DIR/codex_plan"
echo ""
echo "═══════════════════════════════════════"
echo "⏳ AWAITING REVIEW"
echo "═══════════════════════════════════════"
echo "Actions:"
echo "  APPROVE  → codex-save.sh \"implement per @var:codex_plan\""
echo "           → aria-coder applies from /tmp/claude_vars/codex_last"
echo "  MODIFY   → edit plan, then approve"
echo "  REJECT   → aria-thinking (Opus) for deep reasoning"
echo ""
