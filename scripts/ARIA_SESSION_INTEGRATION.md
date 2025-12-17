# ARIA Session Integration Guide

How to integrate session memory into `aria-route.sh` and other ARIA tools.

## Integration Points

### 1. Load Session System at Startup

Add to any script that uses sessions:

```bash
source ~/.claude/scripts/aria-session.sh 2>/dev/null
```

### 2. Auto-Initialize Session on First Run

Ensure a session exists:

```bash
_aria_session_ensure  # Creates first session if needed
```

### 3. Track LLM Calls with Context

When calling an LLM route, include previous context:

```bash
#!/bin/bash
source ~/.claude/scripts/aria-session.sh

# Get the new user request
user_input="$1"

# Build prompt with previous context
prompt=$(aria_session_build_prompt "$user_input")

# Call LLM with context
response=$(aria route general "$prompt")

# Record conversation
aria_session_add_user "$user_input" "gpt-5.1"
aria_session_add_assistant "$response" "gpt-5.1"

# Display response
echo "$response"
```

## Enhanced aria-route.sh Pattern

```bash
#!/bin/bash
source ~/.claude/scripts/aria-route.sh
source ~/.claude/scripts/aria-session.sh

aria_route_with_memory() {
    local task_type="$1"
    shift
    local user_prompt="$*"

    # Build context-aware prompt
    local full_prompt=$(aria_session_build_prompt "$user_prompt" 4000)

    # Route to model
    local response=$(aria_route "$task_type" "$full_prompt")

    # Record in session
    aria_session_add_user "$user_prompt"
    aria_session_add_assistant "$response"

    # Return response
    echo "$response"
}
```

## Common Patterns

### Pattern 1: Multi-Turn Conversation

```bash
source ~/.claude/scripts/aria-session.sh

# Turn 1
aria_session_add_user "What's 2+2?"
response=$(aria route instant "$(aria_session_build_prompt 'What is 2+2?')")
aria_session_add_assistant "$response"
echo "Response: $response"

# Turn 2 (context automatically included)
aria_session_add_user "Multiply by 3"
response=$(aria route instant "$(aria_session_build_prompt 'Multiply by 3')")
aria_session_add_assistant "$response"
echo "Response: $response"
```

### Pattern 2: Parallel Sessions

```bash
source ~/.claude/scripts/aria-session.sh

# Start debugging session
debug_session=$(aria_session_init)
aria_session_switch "$debug_session"
aria_session_add_user "Debug this function"
# ... debug work ...

# Switch back to main session
aria_session_switch "$main_session"
aria_session_add_user "Continue with implementation"
# ... implementation work ...
```

### Pattern 3: Context-Limited Requests

```bash
source ~/.claude/scripts/aria-session.sh

# Get context fitting within token limit
context=$(aria_session_get_context 2000)  # 2K tokens max

# Build prompt with limited context
prompt=$(cat <<EOF
$context

New request: Summarize the above conversation
EOF
)

response=$(aria route instant "$prompt")
aria_session_add_assistant "$response" "gpt-5.1-codex-mini"
```

### Pattern 4: Maintaining Separate Tracks

```bash
source ~/.claude/scripts/aria-session.sh

# Create sessions for different purposes
analysis_session=$(aria_session_init)
implementation_session=$(aria_session_init)

# Work on analysis
aria_session_switch "$analysis_session"
aria_session_add_user "Analyze the architecture"
aria_session_add_assistant "Architecture analysis..."

# Work on implementation
aria_session_switch "$implementation_session"
aria_session_add_user "Implement feature X"
aria_session_add_assistant "Implementation plan..."

# Back to analysis
aria_session_switch "$analysis_session"
aria_session_add_user "What about security?"
# ... continues with analysis context ...
```

## Best Practices

### 1. Initialize on Entry Point

Always ensure session is initialized at script start:

```bash
_aria_session_ensure
```

### 2. Record Both User and Assistant

Always record both sides of the conversation:

```bash
aria_session_add_user "$prompt"
response=$(aria route general "$prompt")
aria_session_add_assistant "$response" "gpt-5.1"
```

### 3. Control Context Size

Use token limits to avoid bloating prompts:

```bash
# Get context that fits in 3K tokens
prompt=$(aria_session_build_prompt "$request" 3000)
```

### 4. Clear Sessions When Done

Clean up old sessions:

```bash
aria_session_delete "session_old_id"
```

### 5. Model Tracking

Always specify the model that generated a response:

```bash
aria_session_add_assistant "$response" "gpt-5.1-codex-max"
```

## Configuration

Set these environment variables to customize behavior:

```bash
export MAX_HISTORY_TURNS=20        # Default: 10
export MAX_CONTEXT_TOKENS=8000     # Default: 4000
```

## Debugging

### View Session Files

```bash
# List all session files
ls -la ~/.claude/cache/sessions/

# View raw JSONL
cat ~/.claude/cache/sessions/session_*.jsonl | jq

# View metadata
cat ~/.claude/cache/sessions/session_*.meta | jq
```

### Check Current Session

```bash
source ~/.claude/scripts/aria-session.sh
aria_session_current
aria_session_show
```

### Inspect Context Building

```bash
source ~/.claude/scripts/aria-session.sh

# See what prompt would be built
aria_session_build_prompt "My request"

# See just history
aria_session_get_history 5

# See context-limited history
aria_session_get_context 2000
```

## Error Handling

### Session Not Found

```bash
if ! aria_session_switch "$id" 2>/dev/null; then
    echo "Session not found, creating new one"
    id=$(aria_session_init)
fi
```

### Token Limit Exceeded

```bash
# Get context that definitely fits
context=$(aria_session_get_context 2000)
if [[ -z "$context" ]]; then
    echo "Session too large, consider archiving"
fi
```

## Migration Path

### From No Sessions to Sessions

1. Source the session script
2. Call `aria_session_init` to create first session
3. Wrap LLM calls with `aria_session_build_prompt`
4. Record responses with `aria_session_add_user` / `aria_session_add_assistant`

### Archiving Old Sessions

```bash
# Save before deletion
cp ~/.claude/cache/sessions/session_*.jsonl ~/archive/

# Clean up
aria_session_delete "session_old_id"
```

## Examples

See `/home/mike/.claude/scripts/ARIA_SESSION_EXAMPLES.sh` for complete working examples.
