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
RED='\033[0;31m'
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

Auto-selection logic (PURPOSE + SIZE):
  implement/write/create:
    - small (<5KB) → tools (OpenRouter)
    - large → codex (best quality)
  review/check/analyze:
    - small (<5KB) → fast (super-fast)
    - medium (<20KB) → qa preset
    - large → codex (file reader)
  explain/summarize:
    - small/no context → fast (super-fast)
    - large context → codex
  browser/click/navigate → browser preset

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

# Detect intent from prompt keywords
detect_intent() {
    local prompt="${1,,}"  # lowercase

    # Code generation patterns
    if [[ "$prompt" =~ (implement|write|create|build|add|generate|refactor|fix|update|modify) ]]; then
        echo "code"
        return
    fi

    # Review/QA patterns
    if [[ "$prompt" =~ (review|check|analyze|audit|validate|test|verify|compare|diff) ]]; then
        echo "review"
        return
    fi

    # Quick question patterns
    if [[ "$prompt" =~ (explain|what is|how does|why|summarize|describe|list|show) ]]; then
        echo "quick"
        return
    fi

    # Browser/UI patterns
    if [[ "$prompt" =~ (browser|click|navigate|screenshot|fill|form|button|page) ]]; then
        echo "browser"
        return
    fi

    # Default to code (most common use case)
    echo "code"
}

# Auto-select best LLM based on PURPOSE + SIZE
# Priority: FREE models (codex/gemini) > cheap OpenRouter > expensive
# OPTIMIZATION: Maximize FREE usage, OpenRouter only for quick checks
auto_select_llm() {
    local prompt="$1"
    local intent=$(detect_intent "$prompt")
    local has_var_refs=$(echo "$prompt" | grep -c '@var:' || echo 0)
    local size=$(get_context_size "$prompt")

    # Size thresholds (bytes)
    local SMALL_CTX=5120      # 5KB - can inline to fast
    local MEDIUM_CTX=20480    # 20KB - OpenRouter max

    case "$intent" in
        code)
            # Code generation → ALWAYS codex (FREE, best quality)
            echo -e "${CYAN}🎯 Intent: code → codex (FREE)${NC}" >&2
            echo "codex"
            ;;
        review)
            # Review → gemini for thorough, fast for quick checks
            if [[ $size -lt $SMALL_CTX && $has_var_refs -eq 0 ]]; then
                echo -e "${CYAN}🎯 Intent: review (quick) → fast${NC}" >&2
                echo "fast"
            else
                echo -e "${CYAN}🎯 Intent: review → gemini (FREE)${NC}" >&2
                echo "gemini"
            fi
            ;;
        quick)
            # Quick questions → fast for tiny, gemini for context
            if [[ $has_var_refs -gt 0 || $size -gt 0 ]]; then
                echo -e "${CYAN}🎯 Intent: quick + context → gemini (FREE)${NC}" >&2
                echo "gemini"
            else
                echo -e "${CYAN}🎯 Intent: quick → fast${NC}" >&2
                echo "fast"
            fi
            ;;
        browser)
            echo -e "${CYAN}🎯 Intent: browser → browser${NC}" >&2
            echo "browser"
            ;;
        *)
            # Default: FREE models based on task type
            if [[ $has_var_refs -gt 0 ]]; then
                # Has context → codex (FREE, can read files)
                echo -e "${CYAN}🎯 Default + context → codex (FREE)${NC}" >&2
                echo "codex"
            else
                # No context → fast (cheapest)
                echo -e "${CYAN}🎯 Default → fast${NC}" >&2
                echo "fast"
            fi
            ;;
    esac
}

# Health check cache (avoid repeated checks within 5 min)
HEALTH_CACHE="/tmp/claude_vars/health_cache"
mkdir -p "$(dirname "$HEALTH_CACHE")" 2>/dev/null

# Check if provider is healthy (responds within timeout)
check_health() {
    local provider="$1"
    local cache_file="${HEALTH_CACHE}_${provider}"

    # Check cache (valid for 5 minutes)
    if [[ -f "$cache_file" ]]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
        if [[ $age -lt 300 ]]; then
            cat "$cache_file"
            return
        fi
    fi

    # Quick health check (2 second timeout)
    local healthy="yes"
    case "$provider" in
        codex)
            timeout 2 codex "hi" >/dev/null 2>&1 || healthy="no"
            ;;
        gemini)
            timeout 2 gemini "hi" >/dev/null 2>&1 || healthy="no"
            ;;
        fast|tools|qa|browser|apply)
            timeout 2 "$SCRIPTS_DIR/ai.sh" fast "hi" >/dev/null 2>&1 || healthy="no"
            ;;
    esac

    echo "$healthy" > "$cache_file"
    echo "$healthy"
}

# Get fallback chain for a provider
get_fallback() {
    local provider="$1"
    case "$provider" in
        codex) echo "gemini fast" ;;
        gemini) echo "codex fast" ;;
        fast|tools|qa) echo "codex gemini" ;;
        browser) echo "fast codex" ;;
        apply) echo "tools codex" ;;
        *) echo "codex gemini" ;;
    esac
}

# Validate response quality
validate_response() {
    local response="$1"
    local min_length="${2:-10}"

    # Check not empty
    [[ -z "$response" ]] && return 1

    # Check minimum length
    [[ ${#response} -lt $min_length ]] && return 1

    # Check for common error patterns
    [[ "$response" =~ ^(Error|error:|ERROR|Failed|failed:) ]] && return 1
    [[ "$response" =~ "rate limit" ]] && return 1
    [[ "$response" =~ "API key" ]] && return 1

    return 0
}

# Call a single provider
call_provider() {
    local provider="$1"
    local prompt="$2"
    local resolved

    case "$provider" in
        codex)
            resolved=$(resolve_for_llm "$prompt" "codex")
            codex "$resolved" 2>/dev/null
            ;;
        gemini)
            resolved=$(resolve_for_llm "$prompt" "gemini")
            gemini "$resolved" 2>/dev/null
            ;;
        fast)
            resolved=$(resolve_for_llm "$prompt" "openrouter")
            "$SCRIPTS_DIR/ai.sh" fast "$resolved" 2>/dev/null
            ;;
        tools)
            resolved=$(resolve_for_llm "$prompt" "openrouter")
            "$SCRIPTS_DIR/ai.sh" tools "$resolved" 2>/dev/null
            ;;
        qa)
            resolved=$(resolve_for_llm "$prompt" "openrouter")
            "$SCRIPTS_DIR/ai.sh" qa "$resolved" 2>/dev/null
            ;;
        browser)
            resolved=$(resolve_for_llm "$prompt" "openrouter")
            "$SCRIPTS_DIR/ai.sh" browser "$resolved" 2>/dev/null
            ;;
        apply)
            resolved=$(resolve_for_llm "$prompt" "openrouter")
            "$SCRIPTS_DIR/ai.sh" apply "$resolved" 2>/dev/null
            ;;
    esac
}

# Dispatch with health check and fallback
dispatch() {
    local provider="$1"
    local prompt="$2"

    # Handle auto mode
    if [[ "$provider" == "auto" || "$provider" == "a" ]]; then
        provider=$(auto_select_llm "$prompt")
    fi

    # Normalize provider name
    case "$provider" in
        c) provider="codex" ;;
        g) provider="gemini" ;;
        f|quick) provider="fast" ;;
        t|code) provider="tools" ;;
        doc|review) provider="qa" ;;
        ui) provider="browser" ;;
        merge|patch) provider="apply" ;;
    esac

    # Build provider chain: primary + fallbacks
    local providers="$provider $(get_fallback "$provider")"
    local response=""
    local used_provider=""

    for p in $providers; do
        # Check health first (skip if unhealthy)
        if [[ $(check_health "$p") == "no" ]]; then
            echo -e "${YELLOW}⚠️  $p unhealthy, skipping${NC}" >&2
            continue
        fi

        echo -e "${GREEN}🤖 Trying $p...${NC}" >&2
        response=$(call_provider "$p" "$prompt")

        # Validate response
        if validate_response "$response"; then
            used_provider="$p"
            break
        else
            echo -e "${YELLOW}⚠️  $p returned invalid response, trying fallback${NC}" >&2
            # Mark as unhealthy for next 5 min
            echo "no" > "${HEALTH_CACHE}_${p}"
        fi
    done

    if [[ -z "$response" ]]; then
        echo -e "${RED}❌ All providers failed${NC}" >&2
        echo "Error: All LLM providers failed to respond"
        return 1
    fi

    if [[ "$used_provider" != "$provider" ]]; then
        echo -e "${CYAN}ℹ️  Used fallback: $used_provider${NC}" >&2
    fi

    echo "$response"
}

# Use enhanced cache manager
CACHE_SCRIPT="$SCRIPTS_DIR/cache-manager.sh"

# Main execution
check_freshness "$PROMPT"

# Handle auto mode resolution for caching
RESOLVED_PROVIDER="$PROVIDER"
if [[ "$PROVIDER" == "auto" || "$PROVIDER" == "a" ]]; then
    RESOLVED_PROVIDER=$(auto_select_llm "$PROMPT")
fi

# Check enhanced cache first
if RESPONSE=$("$CACHE_SCRIPT" get "$RESOLVED_PROVIDER" "$PROMPT" 2>&1); then
    # Cache hit - response already set (filter out status message)
    RESPONSE=$(echo "$RESPONSE" | grep -v "^⚡ Cache hit" || echo "$RESPONSE")
else
    # Cache miss - call LLM
    RESPONSE=$(dispatch "$PROVIDER" "$PROMPT")

    # Save to enhanced cache
    "$CACHE_SCRIPT" set "$RESOLVED_PROVIDER" "$PROMPT" "$RESPONSE"
fi

# Save response
echo "$RESPONSE" | "$SCRIPTS_DIR/var.sh" save "llm_response_last" - "$PROVIDER: ${PROMPT:0:50}" >/dev/null

echo "$RESPONSE"
