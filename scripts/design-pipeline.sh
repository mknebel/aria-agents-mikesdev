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
echo "▶ Running 3 LLMs in parallel..."
echo "  - Claude Opus 4.5 (aria-ui-ux agent)"
echo "  - Gemini (latest)"
echo "  - Codex (latest)"
echo ""

# Gemini Pro (background)
echo "  Starting Gemini Pro..."
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

# Codex Max (background)
echo "  Starting Codex Max..."
(
    if command -v codex &> /dev/null; then
        codex exec "$DESIGN_PROMPT" 2>/dev/null > "$VAR_DIR/codex_design" || echo "Codex failed" > "$VAR_DIR/codex_design"
    else
        echo "Codex CLI not available" > "$VAR_DIR/codex_design"
    fi
) &
CODEX_PID=$!

# Wait for both background processes
echo ""
echo "  Waiting for parallel completion..."
wait $GEMINI_PID 2>/dev/null || true
echo "  ✓ Gemini Pro complete"
wait $CODEX_PID 2>/dev/null || true
echo "  ✓ Codex Max complete"
echo ""

# Create combined output for Claude
echo "═══════════════════════════════════════"
echo "📝 DESIGN OUTPUTS (for Claude to compare)"
echo "═══════════════════════════════════════"

cat > "$VAR_DIR/design_comparison" << COMPARISON
# Design Comparison: $TASK

## Gemini Pro Design
$(cat "$VAR_DIR/gemini_design")

---

## Codex Max Design
$(cat "$VAR_DIR/codex_design")

---

## Instructions for Claude
1. Review both designs above
2. Launch Task(aria-ui-ux, opus) with same requirements for 3rd perspective
3. **EVALUATE each design:**
   | Aspect | Gemini | Codex | Opus | Winner |
   |--------|--------|-------|------|--------|
   | Component structure | | | | |
   | Styling approach | | | | |
   | Accessibility | | | | |
   | Code quality | | | | |
   | Responsiveness | | | | |
   | UX/Interactions | | | | |

4. **CHOOSE ONE:**
   - **Option A: Pick Best** - If one design clearly wins most categories
   - **Option B: Merge Best** - Take BEST points from each, OMIT worst points
     - Do NOT average or compromise
     - Cherry-pick winning elements only
     - Discard weak implementations entirely

5. Implement winning/merged design
6. Run quality-gate.sh

## Variables Available
- \$gemini_design - Gemini Pro output
- \$codex_design - Codex Max output
- \$design_comparison - This comparison file
COMPARISON

echo ""
cat "$VAR_DIR/design_comparison"
echo ""
echo "═══════════════════════════════════════"
echo "⏳ AWAITING CLAUDE + OPUS"
echo "═══════════════════════════════════════"
echo "Variables created:"
echo "  \$gemini_design      - Gemini Pro design"
echo "  \$codex_design       - Codex Max design"
echo "  \$design_comparison  - Combined for review"
echo ""
echo "Next: Claude should launch Task(aria-ui-ux, opus) for 3rd design,"
echo "      then compare all 3 and implement best."
echo ""
