# ARIA Session - Quick Reference

## CLI Commands

```bash
# Initialize and manage
aria-session.sh new              # Create new session
aria-session.sh current          # Show current session ID
aria-session.sh list             # List all sessions
aria-session.sh show             # Display conversation
aria-session.sh switch <id>      # Switch to session
aria-session.sh clear            # Clear session history
aria-session.sh delete <id>      # Delete session
aria-session.sh help             # Show help
```

## Shell Functions (source the script)

```bash
source ~/.claude/scripts/aria-session.sh

# Session management
aria_session_init                           # Create new session
aria_session_current                        # Get current session ID
aria_session_list                           # List sessions
aria_session_switch "$id"                   # Switch sessions
aria_session_clear                          # Clear history
aria_session_delete "$id"                   # Delete session

# Message management
aria_session_add_user "$msg" [$model]       # Add user message
aria_session_add_assistant "$msg" [$model]  # Add response

# Context building
aria_session_get_history [$turns]           # Get last N turns
aria_session_get_context [$tokens]          # Get context by token limit
aria_session_build_prompt "$msg" [$tokens]  # Build prompt with context
aria_session_show                           # Display conversation

# Utility
_aria_session_ensure                        # Ensure session exists
```

## Common Workflows

### Basic Conversation
```bash
source ~/.claude/scripts/aria-session.sh

# Add user message
aria_session_add_user "What is 2+2?"

# Add response
aria_session_add_assistant "2+2 equals 4"

# View conversation
aria_session_show
```

### Multi-Turn with Context
```bash
source ~/.claude/scripts/aria-session.sh

# Turn 1
aria_session_add_user "First question"
aria_session_add_assistant "First answer"

# Turn 2 (context auto-included)
prompt=$(aria_session_build_prompt "Follow-up question")
response=$(aria route general "$prompt")
aria_session_add_user "Follow-up question"
aria_session_add_assistant "$response"
```

### Parallel Sessions
```bash
source ~/.claude/scripts/aria-session.sh

# Create sessions
debug=$(aria_session_init)
feature=$(aria_session_init)

# Work on debug
aria_session_switch "$debug"
aria_session_add_user "Debug issue"
aria_session_add_assistant "Found the bug"

# Work on feature
aria_session_switch "$feature"
aria_session_add_user "Build feature"
aria_session_add_assistant "Feature plan"

# Back to debug
aria_session_switch "$debug"
aria_session_add_user "Follow-up"
```

### Context-Limited Prompts
```bash
source ~/.claude/scripts/aria-session.sh

# Get context fitting 2K tokens
context=$(aria_session_get_context 2000)

# Build prompt
prompt="$context

New request: Summarize above"

response=$(aria route general "$prompt")
```

## Storage Locations

```
~/.claude/cache/sessions/
├── current                    # Current session symlink
├── session_*.jsonl            # Conversation history
└── session_*.meta             # Metadata (JSON)
```

## Configuration

```bash
# In environment or script
export MAX_HISTORY_TURNS=10       # Turns to keep in memory
export MAX_CONTEXT_TOKENS=4000    # Default token limit
```

## Debugging

```bash
source ~/.claude/scripts/aria-session.sh

# Check current session
aria_session_current

# Show full history
aria_session_show

# View raw JSONL
cat ~/.claude/cache/sessions/$(aria_session_current).jsonl | jq

# Get just last 3 turns
aria_session_get_history 3 | jq

# Get context for 1K tokens
aria_session_get_context 1000 | wc -l
```

## Integration Template

```bash
#!/bin/bash
source ~/.claude/scripts/aria-session.sh
source ~/.claude/scripts/aria-route.sh

# Ensure session exists
_aria_session_ensure

# Build context-aware prompt
prompt=$(aria_session_build_prompt "$1")

# Call LLM
response=$(aria route general "$prompt")

# Record conversation
aria_session_add_user "$1"
aria_session_add_assistant "$response"

# Output result
echo "$response"
```

## Examples

Run complete examples:
```bash
/home/mike/.claude/scripts/ARIA_SESSION_EXAMPLES.sh 1    # Basic conversation
/home/mike/.claude/scripts/ARIA_SESSION_EXAMPLES.sh 2    # Parallel sessions
/home/mike/.claude/scripts/ARIA_SESSION_EXAMPLES.sh 3    # Context management
/home/mike/.claude/scripts/ARIA_SESSION_EXAMPLES.sh all  # All examples
```

## Key Features

- **Persistent context** across CLI calls
- **Multiple sessions** for parallel work
- **Token-aware** context fitting
- **JSON storage** for easy parsing
- **Metadata tracking** (times, counts, models)
- **Session switching** for context switching
- **History management** with automatic truncation
- **Model tracking** per message

## Best Practices

1. Always call `_aria_session_ensure` at script start
2. Specify model name when adding messages: `aria_session_add_user "$msg" "gpt-5.1"`
3. Use `aria_session_build_prompt` to include context
4. Control context size with token limits: `aria_session_get_context 2000`
5. Record both user and assistant messages
6. Clean up old sessions: `aria_session_delete "$id"`
7. Switch sessions for parallel work: `aria_session_switch "$id"`

## Error Handling

```bash
# Check if session exists
if ! aria_session_switch "$id" 2>/dev/null; then
    echo "Creating new session"
    aria_session_init
fi

# Check context size
if [[ -z "$(aria_session_get_context 1000)" ]]; then
    echo "Session too large"
fi
```
