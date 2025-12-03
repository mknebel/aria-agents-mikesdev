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
CACHE_DIR="/tmp/claude_vars/cache"
SCRIPTS_DIR="$HOME/.claude/scripts"
mkdir -p "$CACHE_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROVIDER="${1:-auto}"
shift
PROMPT="$*"

[[ -z "$PROMPT" ]] && {
    cat << 'HELP'
llm.sh - Smart LLM dispatcher

Usage: llm <provider> "prompt with @var:references"

Providers:
  auto     Auto-select based on context size (recommended)
  codex    OpenAI Codex (reads files via @file:)
  gemini   Google Gemini (reads files via @path)
  fast     DeepSeek via OpenRouter (inlines content)
  tools    Tool-use preset (inlines content)
  qa       QA/Doc preset (inlines content)

Auto-selection logic:
  <1KB   → fast (cheapest, quickest)
  1-20KB → gemini (free, good quality)
  >20KB  → codex (can read large files)

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

# Calculate total context size from @var: references
get_context_size() {
    local prompt="$1"
    local total=0

    local vars=$(echo "$prompt" | grep -oE '@var:[a-zA-Z0-9_]+' || true)
    for ref in $vars; do
        local var_name="${ref#@var:}"
        local var_file="$VAR_DIR/${var_name}.txt"
        if [[ -f "$var_file" ]]; then
            total=$((total + $(wc -c < "$var_file")))
        fi
    done

    echo "$total"
}

# Auto-select best LLM based on context size
# Note: Gemini can't read /tmp files, so we use codex for @var: refs
auto_select_llm() {
    local prompt="$1"
    local size=$(get_context_size "$prompt")
    local has_var_refs=$(echo "$prompt" | grep -c '@var:' || echo 0)

    if [[ $size -lt 1024 ]]; then
        echo -e "${CYAN}📊 Context: ${size}B → fast (quick)${NC}" >&2
        echo "fast"
    elif [[ $has_var_refs -gt 0 ]]; then
        # Use codex for @var: refs (can read files anywhere)
        echo -e "${CYAN}📊 Context: ${size}B + @var: → codex (file access)${NC}" >&2
        echo "codex"
    elif [[ $size -lt 20480 ]]; then
        echo -e "${CYAN}📊 Context: ${size}B → fast (inline)${NC}" >&2
        echo "fast"
    else
        echo -e "${CYAN}📊 Context: ${size}B → codex (large files)${NC}" >&2
        echo "codex"
    fi
}

# Dispatch to appropriate LLM
dispatch() {
    local provider="$1"
    local prompt="$2"

    # Handle auto mode
    if [[ "$provider" == "auto" || "$provider" == "a" ]]; then
        provider=$(auto_select_llm "$prompt")
    fi

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

# Generate cache key from provider + prompt + var contents
get_cache_key() {
    local provider="$1"
    local prompt="$2"

    # Build hash input: provider + prompt + var file hashes
    local hash_input="$provider|$prompt"

    local vars=$(echo "$prompt" | grep -oE '@var:[a-zA-Z0-9_]+' || true)
    for ref in $vars; do
        local var_name="${ref#@var:}"
        local var_file="$VAR_DIR/${var_name}.txt"
        if [[ -f "$var_file" ]]; then
            hash_input+="|$(md5sum "$var_file" | cut -d' ' -f1)"
        fi
    done

    echo "$hash_input" | md5sum | cut -d' ' -f1
}

# Check cache (returns 0 if hit, 1 if miss)
check_cache() {
    local cache_key="$1"
    local cache_file="$CACHE_DIR/${cache_key}.txt"
    local cache_meta="$CACHE_DIR/${cache_key}.meta"

    [[ ! -f "$cache_file" ]] && return 1
    [[ ! -f "$cache_meta" ]] && return 1

    # Check freshness (1 hour max)
    local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
    if [[ $cache_age -gt 3600 ]]; then
        return 1
    fi

    echo -e "${GREEN}⚡ Cache hit (${cache_age}s old)${NC}" >&2
    cat "$cache_file"
    return 0
}

# Save to cache
save_cache() {
    local cache_key="$1"
    local response="$2"
    local provider="$3"
    local prompt="$4"

    local cache_file="$CACHE_DIR/${cache_key}.txt"
    local cache_meta="$CACHE_DIR/${cache_key}.meta"

    echo "$response" > "$cache_file"
    echo "${provider}|${prompt:0:100}" > "$cache_meta"
}

# Main execution
check_freshness "$PROMPT"

# Check cache first
CACHE_KEY=$(get_cache_key "$PROVIDER" "$PROMPT")
if RESPONSE=$(check_cache "$CACHE_KEY"); then
    # Cache hit - response already set
    :
else
    # Cache miss - call LLM
    RESPONSE=$(dispatch "$PROVIDER" "$PROMPT")
    save_cache "$CACHE_KEY" "$RESPONSE" "$PROVIDER" "$PROMPT"
fi

# Save response
echo "$RESPONSE" | "$SCRIPTS_DIR/var.sh" save "llm_response_last" - "$PROVIDER: ${PROMPT:0:50}" >/dev/null

echo "$RESPONSE"
