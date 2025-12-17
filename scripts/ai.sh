#!/bin/bash
# Unified AI tool - uses your existing subscriptions + OpenRouter
# Usage: ai.sh <tool> "prompt" [files...]
#
# Tools:
#   codex   - OpenAI Codex (your GPT account) - code review/generation
#   gemini  - Google Gemini (your Google account) - search/analysis
#   fast    - DeepSeek (fastest, cheapest)
#   qa      - QA/Doc preset (3 models, works)
#   tools   - Qwen Coder (code generation)
#   browser - DeepSeek (browser/UI prompts)
#
# All outputs saved to /tmp/claude_vars/{tool}_last

TOOL="${1:-fast}"
shift
PROMPT="$*"

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

save_and_output() {
    local tool_name="$1"
    local output="$2"
    echo "$output" > "$VAR_DIR/${tool_name}_last"
    echo "$output"
}

call_openrouter() {
    local model="$1"
    local prompt="$2"
    local label="$3"

    KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
    [ -z "$KEY" ] && echo "Error: No OpenRouter key" >&2 && exit 1

    echo "$label" >&2
    START=$(date +%s.%N)

    API_RESULT=$(curl -s https://openrouter.ai/api/v1/chat/completions \
        -H "Authorization: Bearer $KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [{\"role\": \"user\", \"content\": $(echo "$prompt" | jq -Rs .)}],
            \"max_tokens\": 8000
        }")

    END=$(date +%s.%N)
    RESULT=$(echo "$API_RESULT" | jq -r '.choices[0].message.content // .error.message')
    save_and_output "openrouter" "$RESULT"
    echo "⏱️ $(echo "$END - $START" | bc)s | 📁 \$openrouter_last" >&2
}

case "$TOOL" in
    codex|c)
        echo "🤖 Codex (GPT)..." >&2
        RESULT=$(codex "$PROMPT" 2>&1)
        save_and_output "codex" "$RESULT"
        echo "📁 \$codex_last" >&2
        ;;

    gemini|g)
        echo "🔍 Gemini..." >&2
        RESULT=$(gemini "$PROMPT" 2>&1)
        save_and_output "gemini" "$RESULT"
        echo "📁 \$gemini_last" >&2
        ;;

    fast|f|quick)
        call_openrouter "@preset/super-fast" "$PROMPT" "⚡ Super Fast preset..."
        ;;

    qa|doc|review)
        call_openrouter "@preset/qa-doc-preset" "$PROMPT" "📋 QA/Doc preset..."
        ;;

    tools|code|implement)
        call_openrouter "@preset/general-non-browser-tools" "$PROMPT" "🔧 Tool-Use preset..."
        ;;

    browser|ui|playwright)
        call_openrouter "@preset/browser-agent-tools-only" "$PROMPT" "🌐 Browser preset..."
        ;;

    apply|merge|patch)
        # Ultra-fast code application via Relace Apply 3
        call_openrouter "relace/relace-apply-3" "$PROMPT" "⚡ Relace Apply (code merge)..."
        ;;

    agent|browser-agent)
        # Full agentic browser automation with persistent session
        ~/.claude/scripts/browser-agent.sh "$PROMPT"
        ;;

    explore)
        # Tools agent - LLM with search/read/list tools
        ~/.claude/scripts/tools-agent.sh "$PROMPT"
        ;;

    search|grep|find)
        # Search codebase and analyze with LLM
        # Usage: ai.sh search "pattern" [path]
        PATTERN="$1"
        shift
        ROOT="${1:-.}"
        echo "🔍 Searching: $PATTERN in $ROOT" >&2
        SEARCH_RESULTS=$(~/.claude/scripts/search.sh "$PATTERN" "$ROOT" 2>/dev/null | head -100)
        if [ -z "$SEARCH_RESULTS" ]; then
            echo "No matches found for: $PATTERN"
            exit 0
        fi
        COMBINED="Analyze these search results for '$PATTERN' and summarize:

$SEARCH_RESULTS

List: file:line - what it does"
        call_openrouter "@preset/general-non-browser-tools" "$COMBINED" "🔧 Analyzing matches..."
        ;;

    ab|ab-test|race)
        # A/B test code generation across multiple models
        ~/.claude/scripts/ab-test.sh "$PROMPT"
        ;;

    ab-report|ab-stats)
        # Show A/B test metrics
        ~/.claude/scripts/ab-metrics.sh report "$@"
        ;;

    *)
        cat << 'HELP'
AI Tool - Unified Interface

Usage: ai.sh <tool> "prompt"

Free (your subscriptions):
  codex   - GPT-4+ (your OpenAI account) - code generation
  gemini  - Gemini (your Google account) - analysis/reasoning

OpenRouter (cheap):
  fast    - Super-fast preset (~$0.001) - quick checks
  qa      - QA/Doc preset (~$0.002) - reviews
  tools   - Tool-use preset (~$0.001) - code generation
  apply   - Relace Apply 3 (~$0.001) - code merging ⚡
  browser - Browser preset (~$0.02) - UI automation

Agents:
  explore - Code explorer (search/read tools)
  search  - Search codebase + analyze
  agent   - Browser automation

A/B Testing:
  ab      - Race multiple models, pick winner
  ab-report - Show win rates and metrics

Output: /tmp/claude_vars/{tool}_last
HELP
        ;;
esac
