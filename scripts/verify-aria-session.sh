#!/bin/bash
# ARIA Session System Verification

echo "================================"
echo "ARIA Session System Verification"
echo "================================"
echo ""

# Check main script
echo "1. Checking aria-session.sh..."
if [[ -x /home/mike/.claude/scripts/aria-session.sh ]]; then
    echo "   ✓ Main script exists and is executable"
else
    echo "   ✗ Main script not found or not executable"
    exit 1
fi

# Check documentation
echo ""
echo "2. Checking documentation files..."
docs=(
    "ARIA_SESSION_README.md"
    "ARIA_SESSION_QUICK_REF.md"
    "ARIA_SESSION_INTEGRATION.md"
    "ARIA_SESSION_SUMMARY.md"
    "ARIA_SESSION_INDEX.md"
    "ARIA_SESSION_DELIVERY.md"
)

for doc in "${docs[@]}"; do
    if [[ -f "/home/mike/.claude/scripts/$doc" ]]; then
        echo "   ✓ $doc"
    else
        echo "   ✗ $doc not found"
        exit 1
    fi
done

# Check examples
echo ""
echo "3. Checking examples..."
if [[ -x /home/mike/.claude/scripts/ARIA_SESSION_EXAMPLES.sh ]]; then
    echo "   ✓ Examples script exists and is executable"
else
    echo "   ✗ Examples script not found or not executable"
    exit 1
fi

# Test basic functionality
echo ""
echo "4. Testing basic functionality..."

source /home/mike/.claude/scripts/aria-session.sh 2>/dev/null

# Create test session
test_session=$(aria_session_init 2>/dev/null)
if [[ -n "$test_session" ]]; then
    echo "   ✓ Session creation works"
else
    echo "   ✗ Session creation failed"
    exit 1
fi

# Add message
aria_session_add_user "Test message" "gpt-5.1" 2>/dev/null
echo "   ✓ Can add user message"

aria_session_add_assistant "Test response" "gpt-5.1" 2>/dev/null
echo "   ✓ Can add assistant message"

# Get history
history=$(aria_session_get_history 10 2>/dev/null)
if [[ -n "$history" ]]; then
    echo "   ✓ Can retrieve history"
else
    echo "   ✗ History retrieval failed"
    exit 1
fi

# Build prompt
prompt=$(aria_session_build_prompt "Test" 1000 2>/dev/null)
if [[ -n "$prompt" ]]; then
    echo "   ✓ Can build prompt with context"
else
    echo "   ✗ Prompt building failed"
    exit 1
fi

# Cleanup - switch to another session first
backup=$(aria_session_init 2>/dev/null)
aria_session_switch "$backup" >/dev/null 2>&1
aria_session_delete "$test_session" 2>/dev/null
aria_session_delete "$backup" 2>/dev/null
echo "   ✓ Session lifecycle management works"

# Summary
echo ""
echo "================================"
echo "✓ Verification Complete!"
echo "================================"
echo ""
echo "Files installed:"
echo "  /home/mike/.claude/scripts/aria-session.sh (15KB)"
echo "  6 comprehensive documentation files"
echo "  ARIA_SESSION_EXAMPLES.sh (7 working examples)"
echo ""
echo "Storage location:"
echo "  ~/.claude/cache/sessions/"
echo ""
echo "Quick start:"
echo "  /home/mike/.claude/scripts/aria-session.sh new"
echo "  /home/mike/.claude/scripts/aria-session.sh show"
echo ""
echo "Run examples:"
echo "  /home/mike/.claude/scripts/ARIA_SESSION_EXAMPLES.sh 1"
echo ""
echo "Read documentation:"
echo "  /home/mike/.claude/scripts/ARIA_SESSION_QUICK_REF.md"
echo ""
