#!/bin/bash
# design-pipeline.sh - Parallel design planning with 3 LLMs
# Usage: design-pipeline.sh "design description" [path]
#
# Flow: Opus + Gemini Pro + Codex Max in PARALLEL → Compare → Best output

set -e

TASK="$1"
SEARCH_PATH="${2:-.}"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

if [ -z "$TASK" ]; then
    echo "Usage: design-pipeline.sh \"design description\" [path]"
    exit 1
fi

echo "═══════════════════════════════════════"
echo "🎨 PARALLEL DESIGN PIPELINE"
echo "═══════════════════════════════════════"
echo "Task: $TASK"
echo "Path: $SEARCH_PATH"
echo ""

DESIGN_PROMPT="Create a UI/UX design for: $TASK

Include:
1. **Component Structure** - HTML/JSX structure
2. **Styling Approach** - CSS/Tailwind classes
3. **Interactions** - User interactions and states
4. **Accessibility** - ARIA labels, keyboard nav
5. **Responsive** - Mobile/tablet/desktop breakpoints
6. **Code** - Implementation-ready code

Be specific and production-ready."

# Run all 3 in parallel using background processes
echo "▶ Running 4 LLMs in parallel..."
echo "  - Claude Opus 4.5 (aria-ui-ux agent) - launched by Claude after"
echo "  - Gemini (latest) - FREE"
echo "  - ChatGPT gpt-5.1 (fast reasoning) - Pro subscription"
echo "  - Codex gpt-5.1-codex-max (agentic) - Pro subscription"
echo ""

# Gemini (background) - FREE
echo "  Starting Gemini..."
(
    if command -v gemini &> /dev/null; then
        cd "$SEARCH_PATH"
        gemini "$DESIGN_PROMPT" @. 2>/dev/null > "$VAR_DIR/gemini_design" || echo "Gemini failed" > "$VAR_DIR/gemini_design"
        cd - > /dev/null
    else
        echo "Gemini CLI not available" > "$VAR_DIR/gemini_design"
    fi
) &
GEMINI_PID=$!

# ChatGPT gpt-5.1 (background) - Fast reasoning, Pro subscription
echo "  Starting ChatGPT (gpt-5.1)..."
(
    if command -v codex &> /dev/null; then
        codex -c model=gpt-5.1 exec "$DESIGN_PROMPT" 2>/dev/null > "$VAR_DIR/chatgpt_design" || echo "ChatGPT failed" > "$VAR_DIR/chatgpt_design"
    else
        echo "Codex CLI not available" > "$VAR_DIR/chatgpt_design"
    fi
) &
CHATGPT_PID=$!

# Codex gpt-5.1-codex-max (background) - Agentic coding, Pro subscription
echo "  Starting Codex (gpt-5.1-codex-max)..."
(
    if command -v codex &> /dev/null; then
        codex exec "$DESIGN_PROMPT" 2>/dev/null > "$VAR_DIR/codex_design" || echo "Codex failed" > "$VAR_DIR/codex_design"
    else
        echo "Codex CLI not available" > "$VAR_DIR/codex_design"
    fi
) &
CODEX_PID=$!

# Wait for all background processes
echo ""
echo "  Waiting for parallel completion..."
wait $GEMINI_PID 2>/dev/null || true
echo "  ✓ Gemini complete"
wait $CHATGPT_PID 2>/dev/null || true
echo "  ✓ ChatGPT (gpt-5.1) complete"
wait $CODEX_PID 2>/dev/null || true
echo "  ✓ Codex (gpt-5.1-codex-max) complete"
echo ""

# Create combined output for Claude
echo "═══════════════════════════════════════"
echo "📝 DESIGN OUTPUTS (for Claude to compare)"
echo "═══════════════════════════════════════"

cat > "$VAR_DIR/design_comparison" << COMPARISON
# Design Comparison: $TASK

## Gemini Design (FREE)
$(cat "$VAR_DIR/gemini_design")

---

## ChatGPT gpt-5.1 Design (Fast Reasoning)
$(cat "$VAR_DIR/chatgpt_design")

---

## Codex gpt-5.1-codex-max Design (Agentic)
$(cat "$VAR_DIR/codex_design")

---

## Instructions for Claude

**YOU ARE THE FINAL LINE OF IMPROVEMENT FOR UI/UX.**

1. Review all 3 drafts above as INPUT material
2. **EVALUATE each draft's strengths:**
   | Aspect | Best From |
   |--------|-----------|
   | Component structure | ? |
   | Styling approach | ? |
   | Accessibility | ? |
   | Code quality | ? |
   | Responsiveness | ? |
   | UX/Interactions | ? |

3. **CREATE THE FINAL DESIGN:**
   - Extract the BEST elements from each draft
   - Discard weak implementations entirely
   - Apply YOUR superior UI/UX expertise to IMPROVE upon all of them
   - Do NOT just pick one - CREATE a refined, polished final version
   - The final design should be BETTER than any single draft

4. Launch Task(aria-ui-ux, opus) with:
   - The original requirements
   - Best elements identified from drafts
   - Instructions to create the FINAL, PRODUCTION-READY design

5. Implement Claude's refined design (not a draft)
6. Run quality-gate.sh

## Variables Available
- \$gemini_design - Gemini output (FREE)
- \$chatgpt_design - ChatGPT gpt-5.1 output (fast)
- \$codex_design - Codex gpt-5.1-codex-max output (agentic)
- \$design_comparison - This comparison file
COMPARISON

echo ""
cat "$VAR_DIR/design_comparison"
echo ""
echo "═══════════════════════════════════════"
echo "⏳ PHASE 2: CLAUDE OPUS FINAL REFINEMENT"
echo "═══════════════════════════════════════"
echo ""
echo "Drafts ready for Claude to refine:"
echo "  \$gemini_design      - Gemini draft (FREE)"
echo "  \$chatgpt_design     - ChatGPT gpt-5.1 draft (fast)"
echo "  \$codex_design       - Codex codex-max draft (agentic)"
echo "  \$design_comparison  - All drafts combined"
echo ""
echo "Claude Opus is the BEST, LAST LINE of UI/UX improvement."
echo "→ Review drafts as INPUT material"
echo "→ Extract best elements from each"
echo "→ Create FINAL design that is BETTER than any draft"
echo "→ Implement the refined, production-ready result"
echo ""
