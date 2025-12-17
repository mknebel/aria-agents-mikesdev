#!/bin/bash
# ARIA Session Management - Practical Examples
# These are reference implementations showing how to use the session system

# ============================================================================
# EXAMPLE 1: Basic Multi-Turn Conversation
# ============================================================================
example_basic_conversation() {
    echo "=== EXAMPLE 1: Basic Multi-Turn Conversation ==="

    source ~/.claude/scripts/aria-session.sh

    # Create new session for this example
    local session=$(aria_session_init)
    echo "Created session: $session"

    # Turn 1: Ask a question
    echo ""
    echo "Turn 1: User asks about math"
    aria_session_add_user "What is 2+2?" "gpt-5.1"
    echo "  User: What is 2+2?"
    local resp1="2+2 equals 4."
    aria_session_add_assistant "$resp1" "gpt-5.1"
    echo "  Assistant: $resp1"

    # Turn 2: Follow-up question with automatic context
    echo ""
    echo "Turn 2: User builds on previous answer"
    aria_session_add_user "Now multiply that by 3" "gpt-5.1"
    echo "  User: Now multiply that by 3"
    local resp2="4 * 3 = 12"
    aria_session_add_assistant "$resp2" "gpt-5.1"
    echo "  Assistant: $resp2"

    # Show what the next turn would look like with context
    echo ""
    echo "Building prompt for Turn 3 (with context):"
    aria_session_build_prompt "What's the answer divided by 6?" | head -15

    # Cleanup (create another temp, switch to it, then delete)
    local temp=$(aria_session_init)
    local another=$(aria_session_init)
    aria_session_switch "$another" >/dev/null
    aria_session_delete "$session" 2>/dev/null
    aria_session_delete "$temp" 2>/dev/null
    aria_session_delete "$another" 2>/dev/null
    echo ""
}

# ============================================================================
# EXAMPLE 2: Parallel Sessions for Different Tasks
# ============================================================================
example_parallel_sessions() {
    echo "=== EXAMPLE 2: Parallel Sessions ==="

    source ~/.claude/scripts/aria-session.sh

    # Create analysis session
    local analysis=$(aria_session_init)
    echo "Created analysis session: $analysis"

    # Create implementation session
    local impl=$(aria_session_init)
    echo "Created implementation session: $impl"

    # Work on analysis
    echo ""
    echo "Switching to analysis session..."
    aria_session_switch "$analysis" >/dev/null
    aria_session_add_user "Analyze the problem" "gpt-5.1"
    aria_session_add_assistant "The problem can be solved by..." "gpt-5.1"
    aria_session_add_user "What are the edge cases?" "gpt-5.1"
    aria_session_add_assistant "Edge cases include..." "gpt-5.1"

    # Work on implementation
    echo "Switching to implementation session..."
    aria_session_switch "$impl" >/dev/null
    aria_session_add_user "Design the implementation" "gpt-5.1-codex"
    aria_session_add_assistant "Here's the implementation plan..." "gpt-5.1-codex"

    # List both sessions
    echo ""
    echo "Listing all sessions:"
    aria_session_list | grep -E "^\*|^ "

    # Cleanup (create another temp, switch to it, then delete)
    local temp=$(aria_session_init)
    local another=$(aria_session_init)
    aria_session_switch "$another" >/dev/null
    aria_session_delete "$analysis" 2>/dev/null
    aria_session_delete "$impl" 2>/dev/null
    aria_session_delete "$temp" 2>/dev/null
    aria_session_delete "$another" 2>/dev/null
    echo ""
}

# ============================================================================
# EXAMPLE 3: Context Management with Token Limits
# ============================================================================
example_context_management() {
    echo "=== EXAMPLE 3: Context Management ==="

    source ~/.claude/scripts/aria-session.sh

    local session=$(aria_session_init)
    echo "Created session: $session"

    # Add many messages to create a large history
    echo ""
    echo "Adding messages to session..."
    for i in {1..5}; do
        aria_session_add_user "Question $i: Tell me about step $i" "gpt-5.1"
        aria_session_add_assistant "Step $i involves several important considerations..." "gpt-5.1"
    done

    # Get full history
    echo ""
    echo "Full history (all turns):"
    aria_session_get_history 20 | wc -l
    echo "  Lines: $(aria_session_get_history 20 | wc -l)"

    # Get limited history (last 2 turns)
    echo ""
    echo "Limited history (last 2 turns):"
    aria_session_get_history 2 | wc -l
    echo "  Lines: $(aria_session_get_history 2 | wc -l)"

    # Get context with token limit
    echo ""
    echo "Context fitting in 500 tokens:"
    aria_session_get_context 500 | wc -l
    echo "  Lines: $(aria_session_get_context 500 | wc -l)"

    echo ""
    echo "Context fitting in 2000 tokens:"
    aria_session_get_context 2000 | wc -l
    echo "  Lines: $(aria_session_get_context 2000 | wc -l)"

    # Cleanup (create another temp, switch to it, then delete)
    local temp=$(aria_session_init)
    local another=$(aria_session_init)
    aria_session_switch "$another" >/dev/null
    aria_session_delete "$session" 2>/dev/null
    aria_session_delete "$temp" 2>/dev/null
    aria_session_delete "$another" 2>/dev/null
    echo ""
}

# ============================================================================
# EXAMPLE 4: Using Sessions with LLM Router
# ============================================================================
example_with_router() {
    echo "=== EXAMPLE 4: Integration with aria-route ==="

    source ~/.claude/scripts/aria-session.sh
    source ~/.claude/scripts/aria-route.sh

    local session=$(aria_session_init)
    echo "Created session: $session"

    # Simulate LLM calls (would be real with actual aria_route calls)
    echo ""
    echo "Simulating multi-turn with routing:"

    # Turn 1: Code review request
    echo ""
    echo "Turn 1: Code review task"
    local req1="Review this function for bugs"
    aria_session_add_user "$req1" "gpt-5.1-codex"
    local resp1="The function looks good but..."
    aria_session_add_assistant "$resp1" "gpt-5.1-codex"
    echo "  User: $req1"
    echo "  Assistant: $resp1"

    # Turn 2: Build on context
    echo ""
    echo "Turn 2: Follow-up with automatic context"
    local req2="Implement the fix you suggested"
    aria_session_add_user "$req2" "gpt-5.1-codex"
    local resp2="Here's the implementation with the fix..."
    aria_session_add_assistant "$resp2" "gpt-5.1-codex"
    echo "  User: $req2"
    echo "  Assistant: $resp2"

    # What would be sent to LLM in Turn 3
    echo ""
    echo "For Turn 3, the LLM would receive:"
    echo "---"
    aria_session_build_prompt "Add error handling" 3000 | head -10
    echo "..."
    echo "---"

    # Cleanup (create another temp, switch to it, then delete)
    local temp=$(aria_session_init)
    local another=$(aria_session_init)
    aria_session_switch "$another" >/dev/null
    aria_session_delete "$session" 2>/dev/null
    aria_session_delete "$temp" 2>/dev/null
    aria_session_delete "$another" 2>/dev/null
    echo ""
}

# ============================================================================
# EXAMPLE 5: Session Management Workflow
# ============================================================================
example_session_management() {
    echo "=== EXAMPLE 5: Session Management ==="

    source ~/.claude/scripts/aria-session.sh

    # Create multiple sessions
    echo "Creating 3 sessions..."
    local s1=$(aria_session_init)
    local s2=$(aria_session_init)
    local s3=$(aria_session_init)

    # Add different content to each
    aria_session_switch "$s1" >/dev/null
    aria_session_add_user "Session 1 content" "gpt-5.1"
    aria_session_add_assistant "Response 1" "gpt-5.1"

    aria_session_switch "$s2" >/dev/null
    aria_session_add_user "Session 2 content" "gpt-5.1"
    aria_session_add_user "More session 2" "gpt-5.1"
    aria_session_add_assistant "Response 2" "gpt-5.1"

    aria_session_switch "$s3" >/dev/null
    # s3 remains empty

    # List all sessions
    echo ""
    echo "Current sessions:"
    aria_session_list

    # Check which is current
    echo "Current session: $(aria_session_current)"

    # Switch and check
    echo ""
    echo "Switching to session 1..."
    aria_session_switch "$s1" >/dev/null
    echo "Now current: $(aria_session_current)"

    # Show content
    echo ""
    echo "Content of session 1:"
    aria_session_show | grep -A 2 "User:" | head -5

    # Cleanup (create another temp, switch to it, then delete)
    echo ""
    echo "Cleaning up sessions..."
    local temp=$(aria_session_init)
    local another=$(aria_session_init)
    aria_session_switch "$another" >/dev/null
    aria_session_delete "$s1" 2>/dev/null
    aria_session_delete "$s2" 2>/dev/null
    aria_session_delete "$s3" 2>/dev/null
    aria_session_delete "$temp" 2>/dev/null
    aria_session_delete "$another" 2>/dev/null
    echo "Done!"
    echo ""
}

# ============================================================================
# EXAMPLE 6: Clearing and Resetting Sessions
# ============================================================================
example_clear_reset() {
    echo "=== EXAMPLE 6: Clearing and Resetting ==="

    source ~/.claude/scripts/aria-session.sh

    local session=$(aria_session_init)
    echo "Created session: $session"

    # Add content
    echo "Adding content..."
    for i in {1..3}; do
        aria_session_add_user "Message $i" "gpt-5.1"
        aria_session_add_assistant "Response $i" "gpt-5.1"
    done

    echo "Session has $(aria_session_get_history 100 | wc -l) lines"

    # Clear session
    echo ""
    echo "Clearing session..."
    aria_session_clear

    echo "After clear: $(aria_session_get_history 100 | wc -l) lines"

    # Can continue using the session
    echo ""
    echo "Adding new content to cleared session..."
    aria_session_add_user "Fresh question" "gpt-5.1"
    aria_session_add_assistant "Fresh answer" "gpt-5.1"

    echo "Final content:"
    aria_session_show | tail -20

    # Cleanup (create another temp, switch to it, then delete)
    local temp=$(aria_session_init)
    local another=$(aria_session_init)
    aria_session_switch "$another" >/dev/null
    aria_session_delete "$session" 2>/dev/null
    aria_session_delete "$temp" 2>/dev/null
    aria_session_delete "$another" 2>/dev/null
    echo ""
}

# ============================================================================
# EXAMPLE 7: Building Complex Prompts with Context
# ============================================================================
example_complex_prompts() {
    echo "=== EXAMPLE 7: Complex Prompt Building ==="

    source ~/.claude/scripts/aria-session.sh

    local session=$(aria_session_init)
    echo "Created session: $session"

    # Build up context
    echo "Building context..."
    aria_session_add_user "Design a payment system" "gpt-5.1"
    aria_session_add_assistant "Consider: security, scalability, compliance" "gpt-5.1"
    aria_session_add_user "What about recurring payments?" "gpt-5.1"
    aria_session_add_assistant "Use webhooks for status updates" "gpt-5.1"

    # Build different prompts with same context
    echo ""
    echo "Prompt 1: Implementation details"
    aria_session_build_prompt "Show me the database schema" 2000 | head -15
    echo "---"

    echo ""
    echo "Prompt 2: Security concerns"
    aria_session_build_prompt "What about PCI compliance?" 2000 | head -15
    echo "---"

    # Cleanup (create another temp, switch to it, then delete)
    local temp=$(aria_session_init)
    local another=$(aria_session_init)
    aria_session_switch "$another" >/dev/null
    aria_session_delete "$session" 2>/dev/null
    aria_session_delete "$temp" 2>/dev/null
    aria_session_delete "$another" 2>/dev/null
    echo ""
}

# ============================================================================
# Run Examples
# ============================================================================

# Show usage
if [[ $# -eq 0 ]]; then
    cat <<EOF
ARIA Session Management Examples

Usage: $0 [example_number]

Available examples:
  1  - Basic multi-turn conversation
  2  - Parallel sessions for different tasks
  3  - Context management with token limits
  4  - Integration with aria-route
  5  - Session management workflow
  6  - Clearing and resetting sessions
  7  - Building complex prompts with context
  all - Run all examples

Examples:
  $0 1         # Run example 1
  $0 all       # Run all examples

EOF
    exit 0
fi

case "$1" in
    1) example_basic_conversation ;;
    2) example_parallel_sessions ;;
    3) example_context_management ;;
    4) example_with_router ;;
    5) example_session_management ;;
    6) example_clear_reset ;;
    7) example_complex_prompts ;;
    all)
        example_basic_conversation
        example_parallel_sessions
        example_context_management
        example_with_router
        example_session_management
        example_clear_reset
        example_complex_prompts
        ;;
    *)
        echo "Unknown example: $1"
        exit 1
        ;;
esac
