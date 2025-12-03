#!/bin/bash
# llm.sh - Smart LLM dispatcher with variable reference handling
#
# Automatically resolves @var: references based on LLM capabilities:
# - Codex/Gemini: Pass file paths (they can read files)
# - OpenRouter: Inline content (max 20KB, truncated if larger)
#
# Usage:
#   llm <provider> "prompt with @var:name references"
#   llm codex "implement X based on @var:ctx_last"
#   llm gemini "analyze @var:grep_last"
#   llm fast "quick question"
#
# Providers:
#   codex    - OpenAI Codex (can read files)
#   gemini   - Google Gemini (can read files)
#   fast     - OpenRouter DeepSeek (inline content)
#   tools    - OpenRouter tool-use preset (inline content)
#   qa       - OpenRouter QA preset (inline content)

set -e

VAR_DIR="/tmp/claude_vars"
SCRIPTS_DIR="$HOME/.claude/scripts"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROVIDER="${1:-fast}"
shift
PROMPT="$*"

[[ -z "$PROMPT" ]] && {
    cat << 'HELP'
llm.sh - Smart LLM dispatcher

Usage: llm <provider> "prompt with @var:references"

Providers:
  codex    OpenAI Codex (reads files via @file:)
  gemini   Google Gemini (reads files via @path)
  fast     DeepSeek via OpenRouter (inlines content)
  tools    Tool-use preset (inlines content)
  qa       QA/Doc preset (inlines content)

Variable References:
  @var:name      Reference to /tmp/claude_vars/name.txt
  @file:path     Direct file reference

Examples:
  llm codex "implement auth based on @var:ctx_last"
  llm gemini "explain @var:grep_last"
  llm fast "summarize: @var:read_last"

The dispatcher automatically:
1. Checks if referenced variables exist
2. Converts @var: to appropriate format per LLM
3. Warns if variables are stale (>5 min)
4. Truncates large content for API-based LLMs
5. Saves response to $llm_response_last
HELP
    exit 0
}

# Check for stale variables and warn
check_freshness() {
    local prompt="$1"
    while [[ "$prompt" =~ @var:([a-zA-Z0-9_]+) ]]; do
        local var_name="${BASH_REMATCH[1]}"
        if ! "$SCRIPTS_DIR/var.sh" fresh "$var_name" 5 2>/dev/null; then
            echo -e "${YELLOW}⚠️  Variable \$${var_name} is >5 min old${NC}" >&2
        fi
        # Remove matched to find next
        prompt="${prompt/@var:$var_name/}"
    done
}

# Resolve variables for specific LLM type
resolve_for_llm() {
    local prompt="$1"
    local llm_type="$2"

    # Find all @var:name references
    local resolved="$prompt"

    # Use grep to find all matches
    local vars=$(echo "$prompt" | grep -oE '@var:[a-zA-Z0-9_]+' | sort -u || true)

    for ref in $vars; do
        local var_name="${ref#@var:}"
        local var_file="$VAR_DIR/${var_name}.txt"

        if [[ ! -f "$var_file" ]]; then
            echo -e "${YELLOW}Warning: Variable not found: $var_name${NC}" >&2
            resolved="${resolved//$ref/[MISSING: $var_name]}"
            continue
        fi

        case "$llm_type" in
            codex)
                # Codex reads files - convert to file reference
                resolved="${resolved//$ref/@$var_file}"
                echo -e "${BLUE}→ $var_name: passing as file ref${NC}" >&2
                ;;
            gemini)
                # Gemini reads files - use @ syntax
                resolved="${resolved//$ref/@$var_file}"
                echo -e "${BLUE}→ $var_name: passing as file ref${NC}" >&2
                ;;
            openrouter|*)
                # OpenRouter needs inline content
                local size=$(wc -c < "$var_file")
                local content

                if [[ $size -gt 20480 ]]; then
                    echo -e "${YELLOW}→ $var_name: truncating ${size}B to 20KB${NC}" >&2
                    content="[Content from \$${var_name} - truncated to 20KB of ${size}B]\n\n$(head -c 20480 "$var_file")\n\n[...truncated...]"
                else
                    echo -e "${BLUE}→ $var_name: inlining ${size}B${NC}" >&2
                    content="[Content from \$${var_name}]\n\n$(cat "$var_file")"
                fi

                # Replace in prompt
                resolved="${resolved//$ref/$content}"
                ;;
        esac
    done

    echo "$resolved"
}

# Dispatch to appropriate LLM
dispatch() {
    local provider="$1"
    local prompt="$2"

    case "$provider" in
        codex|c)
            local resolved=$(resolve_for_llm "$prompt" "codex")
            echo -e "${GREEN}🤖 Codex${NC}" >&2
            codex "$resolved"
            ;;

        gemini|g)
            local resolved=$(resolve_for_llm "$prompt" "gemini")
            echo -e "${GREEN}🔍 Gemini${NC}" >&2
            gemini "$resolved"
            ;;

        fast|f|quick)
            local resolved=$(resolve_for_llm "$prompt" "openrouter")
            echo -e "${GREEN}⚡ Fast (DeepSeek)${NC}" >&2
            "$SCRIPTS_DIR/ai.sh" fast "$resolved"
            ;;

        tools|t|code)
            local resolved=$(resolve_for_llm "$prompt" "openrouter")
            echo -e "${GREEN}🔧 Tools preset${NC}" >&2
            "$SCRIPTS_DIR/ai.sh" tools "$resolved"
            ;;

        qa|doc|review)
            local resolved=$(resolve_for_llm "$prompt" "openrouter")
            echo -e "${GREEN}📋 QA preset${NC}" >&2
            "$SCRIPTS_DIR/ai.sh" qa "$resolved"
            ;;

        browser|ui)
            local resolved=$(resolve_for_llm "$prompt" "openrouter")
            echo -e "${GREEN}🌐 Browser preset${NC}" >&2
            "$SCRIPTS_DIR/ai.sh" browser "$resolved"
            ;;

        *)
            echo "Unknown provider: $provider" >&2
            echo "Use: codex, gemini, fast, tools, qa, browser" >&2
            exit 1
            ;;
    esac
}

# Main execution
check_freshness "$PROMPT"
RESPONSE=$(dispatch "$PROVIDER" "$PROMPT")

# Save response
echo "$RESPONSE" | "$SCRIPTS_DIR/var.sh" save "llm_response_last" - "$PROVIDER: ${PROMPT:0:50}" >/dev/null

echo "$RESPONSE"
