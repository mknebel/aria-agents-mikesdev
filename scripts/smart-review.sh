#!/bin/bash
# Smart code review: Codex first, Claude fallback
# Usage: smart-review.sh <file_or_description>

INPUT="$*"
REVIEW_FILE="/tmp/claude_vars/review_last"

echo "🔍 Running Codex review first..."

# Try codex review
if command -v codex &> /dev/null; then
    RESULT=$(codex "review: $INPUT" 2>&1)
    EXIT_CODE=$?

    # Check if codex succeeded and produced meaningful output
    if [[ $EXIT_CODE -eq 0 && ${#RESULT} -gt 100 ]]; then
        echo "$RESULT"
        echo "$RESULT" > "$REVIEW_FILE"
        echo ""
        echo "✅ Codex review complete. Saved to \$review_last"
        echo "💡 If you need deeper analysis, run: /mode aria then ask Claude to review"
        exit 0
    else
        echo "⚠️ Codex review failed or insufficient. Falling back to Claude..."
    fi
else
    echo "⚠️ Codex not available. Suggesting Claude review..."
fi

# Fallback message
cat << EOF

🔄 FALLBACK: Use Claude for this review

Claude advantage: Reviews AND implements fixes (Codex only identifies issues)

Option 1: Quick Claude review (current mode)
  Just ask: "review and fix: $INPUT"

Option 2: Full Claude agent review
  /mode aria
  Then: "review this code and implement any fixes"

Claude will:
  1. Identify issues (like Codex)
  2. Suggest improvements
  3. Actually implement the fixes ← Codex can't do this

EOF
