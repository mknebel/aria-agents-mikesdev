#!/bin/bash
# Tools Agent - LLM with access to local tools (search, read, etc.)
# Uses OpenRouter with tool calling
#
# Usage:
#   tools-agent.sh "find all authentication code and explain it"
#   tools-agent.sh "search for database queries in src/"

set -e

MAX_ITERATIONS=15
OPENROUTER_KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
MODEL="deepseek/deepseek-chat"
VAR_DIR="/tmp/claude_vars"
LOG_FILE="$VAR_DIR/tools-agent.log"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

mkdir -p "$VAR_DIR"

TASK="$*"
[ -z "$TASK" ] && echo "Usage: tools-agent.sh \"task\"" && exit 1
[ -z "$OPENROUTER_KEY" ] && echo "Error: No OpenRouter API key" && exit 1

echo "=== Tools Agent ===" > "$LOG_FILE"
echo "Task: $TASK" >> "$LOG_FILE"

# System prompt with tools
SYSTEM_PROMPT='You are a code assistant with access to tools. Execute tasks step by step.

TOOLS (respond with ONE JSON command per message):
{"tool":"search","pattern":"regex","path":"dir"}  - Search code with ripgrep
{"tool":"read","file":"path/to/file"}             - Read a file
{"tool":"list","path":"dir"}                      - List directory contents
{"tool":"done","summary":"final answer"}          - Task complete
{"tool":"fail","reason":"why"}                    - Cannot complete

RULES:
1. ONE tool call per response as raw JSON
2. Use search to find relevant code
3. Use read to examine specific files
4. Provide done with a complete answer when finished
5. No markdown, just JSON'

HISTORY=""

call_llm() {
    local msg="$1"
    local messages="[{\"role\":\"system\",\"content\":$(echo "$SYSTEM_PROMPT" | jq -Rs .)}$HISTORY,{\"role\":\"user\",\"content\":$(echo "$msg" | jq -Rs .)}]"

    local resp=$(curl -s https://openrouter.ai/api/v1/chat/completions \
        -H "Authorization: Bearer $OPENROUTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":$messages,\"max_tokens\":2000}")

    local content=$(echo "$resp" | jq -r '.choices[0].message.content // "Error"')
    HISTORY="$HISTORY,{\"role\":\"user\",\"content\":$(echo "$msg" | jq -Rs .)},{\"role\":\"assistant\",\"content\":$(echo "$content" | jq -Rs .)}"
    echo "$content"
}

run_tool() {
    local json="$1"
    local tool=$(echo "$json" | jq -r '.tool')

    case "$tool" in
        search)
            local pattern=$(echo "$json" | jq -r '.pattern')
            local path=$(echo "$json" | jq -r '.path // "."')
            rg -n --hidden --glob '!.git' "$pattern" "$path" 2>/dev/null | head -50
            ;;
        read)
            local file=$(echo "$json" | jq -r '.file')
            if [ -f "$file" ]; then
                head -200 "$file"
            else
                echo "File not found: $file"
            fi
            ;;
        list)
            local path=$(echo "$json" | jq -r '.path // "."')
            ls -la "$path" 2>/dev/null | head -50
            ;;
        done|fail)
            echo "$json"
            ;;
        *)
            echo "Unknown tool: $tool"
            ;;
    esac
}

extract_json() {
    echo "$1" | grep -oP '\{[^{}]*\}' | head -1
}

echo "🔧 Tools Agent" >&2
echo "📋 Task: $TASK" >&2
echo "" >&2

iter=0
msg="Task: $TASK

Use the available tools to complete this task. Start with your first tool call."

while [ $iter -lt $MAX_ITERATIONS ]; do
    iter=$((iter + 1))
    echo "━━━ Step $iter ━━━" >&2

    echo "🧠 Thinking..." >&2
    resp=$(call_llm "$msg")
    echo "$resp" >> "$LOG_FILE"

    json=$(extract_json "$resp")
    [ -z "$json" ] && { msg="Respond with JSON tool call: {\"tool\":\"...\"}"; continue; }

    tool=$(echo "$json" | jq -r '.tool')
    echo "🔧 $tool" >&2

    if [ "$tool" = "done" ]; then
        summary=$(echo "$json" | jq -r '.summary // "Complete"')
        echo "" >&2
        echo "✅ Done" >&2
        echo "$summary"
        exit 0
    fi

    if [ "$tool" = "fail" ]; then
        reason=$(echo "$json" | jq -r '.reason // "Failed"')
        echo "❌ $reason" >&2
        exit 1
    fi

    echo "⚡ Running..." >&2
    result=$(run_tool "$json" 2>&1)
    result_preview=$(echo "$result" | head -20)
    echo "📤 $(echo "$result_preview" | head -3 | tr '\n' ' ')..." >&2

    msg="Tool result:
$result_preview

Continue with next tool or provide done with your final answer."
    echo "" >&2
done

echo "⚠️ Max iterations" >&2
exit 1
