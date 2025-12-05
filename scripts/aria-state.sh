#!/bin/bash
# ARIA Session State Management
# Tracks operations, models, timing for efficiency scoring

ARIA_DIR="$HOME/.claude"
ARIA_STATE="$ARIA_DIR/.aria-state"
ARIA_FILES="$ARIA_DIR/.aria-files"
ARIA_LOCK="$ARIA_DIR/.aria.lock"

aria_init() {
    mkdir -p "$ARIA_DIR"
    cat > "$ARIA_STATE" << EOF
{
  "session_id": "$(uuidgen 2>/dev/null | cut -c1-8 || echo "$(date +%s)-$$")",
  "started": $(date +%s),
  "cwd": "$(pwd)",
  "reads": 0,
  "writes": 0,
  "greps": 0,
  "tasks": 0,
  "external": 0,
  "cache_hits": 0,
  "cache_misses": 0,
  "tool_calls": 0,
  "tool_success": 0,
  "tool_fail": 0,
  "timing": {
    "api_ms": 0,
    "tool_ms": 0
  },
  "models": {
    "claude_opus": 0,
    "claude_haiku": 0,
    "codex_max": 0,
    "codex_mini": 0,
    "codex": 0,
    "gpt51": 0,
    "gemini": 0
  },
  "tokens": {
    "claude_in": 0,
    "claude_out": 0,
    "external_in": 0,
    "external_out": 0
  }
}
EOF
    : > "$ARIA_FILES"
}

aria_get() {
    jq -r ".$1 // 0" "$ARIA_STATE" 2>/dev/null
}

aria_inc() {
    local key="$1"
    local amt="${2:-1}"
    (
        flock -x 200 2>/dev/null || true
        local val=$(jq -r ".$key // 0" "$ARIA_STATE" 2>/dev/null)
        val=$((val + amt))
        jq ".$key = $val" "$ARIA_STATE" > "${ARIA_STATE}.tmp" 2>/dev/null
        mv "${ARIA_STATE}.tmp" "$ARIA_STATE" 2>/dev/null
    ) 200>"$ARIA_LOCK"
}

aria_set() {
    local key="$1" val="$2"
    (
        flock -x 200 2>/dev/null || true
        jq ".$key = $val" "$ARIA_STATE" > "${ARIA_STATE}.tmp" 2>/dev/null
        mv "${ARIA_STATE}.tmp" "$ARIA_STATE" 2>/dev/null
    ) 200>"$ARIA_LOCK"
}

aria_track_file() {
    local file="$1" op="$2"
    local mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    local size=$(stat -c %s "$file" 2>/dev/null || echo 0)

    # Check if cached (hit) or new (miss)
    if grep -q "|${file}$" "$ARIA_FILES" 2>/dev/null; then
        local cached_mtime=$(grep "|${file}$" "$ARIA_FILES" | tail -1 | cut -d'|' -f1)
        if [[ "$mtime" == "$cached_mtime" ]]; then
            aria_inc "cache_hits"
        else
            aria_inc "cache_misses"
        fi
    else
        aria_inc "cache_misses"
    fi

    # LRU cache - keep last 100
    grep -v "|${file}$" "$ARIA_FILES" 2>/dev/null | tail -99 > "${ARIA_FILES}.tmp" || true
    echo "${mtime}|${size}|${op}|$(date +%s)|${file}" >> "${ARIA_FILES}.tmp"
    mv "${ARIA_FILES}.tmp" "$ARIA_FILES" 2>/dev/null
}

aria_file_changed() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0
    local current=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    local cached=$(grep "|${file}$" "$ARIA_FILES" 2>/dev/null | tail -1 | cut -d'|' -f1)
    [[ -z "$cached" ]] && return 0
    [[ "$current" != "$cached" ]]
}

aria_log_model() {
    local model="$1"
    aria_inc "models.${model}"
}

aria_log_tokens() {
    local type="$1" input="$2" output="$3"
    aria_inc "tokens.${type}_in" "$input"
    aria_inc "tokens.${type}_out" "$output"
}

aria_log_tool() {
    local success="$1"
    aria_inc "tool_calls"
    if [[ "$success" == "true" || "$success" == "1" ]]; then
        aria_inc "tool_success"
    else
        aria_inc "tool_fail"
    fi
}

# Auto-init if stale (>4 hours) or missing
if [[ ! -f "$ARIA_STATE" ]] || [[ $(($(date +%s) - $(aria_get started))) -gt 14400 ]]; then
    aria_init
fi
