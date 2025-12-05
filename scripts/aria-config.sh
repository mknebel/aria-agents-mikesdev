#!/bin/bash
# ARIA Configuration - Shared constants and temp directory management
# Source this in any ARIA script: source ~/.claude/scripts/aria-config.sh

# =============================================================================
# TEMP DIRECTORIES
# =============================================================================

# Global temp - for cross-agent communication (rare)
ARIA_GLOBAL_TEMP="/tmp/aria-global"
ARIA_GLOBAL_TEMP_WIN="/mnt/c/temp/aria-global"

# Project temp - based on working directory hash (most common)
_aria_project_hash() {
    echo -n "$(pwd)" | md5sum | cut -c1-8
}

ARIA_PROJECT_TEMP="/tmp/aria-$(_aria_project_hash)"
ARIA_PROJECT_TEMP_WIN="/mnt/c/temp/aria-$(_aria_project_hash)"

# Convenience aliases
ARIA_TEMP="$ARIA_PROJECT_TEMP"           # Default to project temp
ARIA_TEMP_WIN="$ARIA_PROJECT_TEMP_WIN"   # Windows-accessible project temp

# =============================================================================
# INITIALIZATION
# =============================================================================

aria_init_temp() {
    # Create all temp directories
    mkdir -p "$ARIA_GLOBAL_TEMP" "$ARIA_PROJECT_TEMP" 2>/dev/null
    mkdir -p "$ARIA_GLOBAL_TEMP_WIN" "$ARIA_PROJECT_TEMP_WIN" 2>/dev/null

    # Store project info for debugging
    echo "$(pwd)" > "$ARIA_PROJECT_TEMP/.project_path" 2>/dev/null
    echo "$(date +%s)" > "$ARIA_PROJECT_TEMP/.created" 2>/dev/null
}

# Auto-init on source
aria_init_temp

# =============================================================================
# CLEANUP HELPERS
# =============================================================================

# Clean project temp (call when done with project)
aria_clean_project() {
    rm -rf "$ARIA_PROJECT_TEMP" "$ARIA_PROJECT_TEMP_WIN" 2>/dev/null
    echo "Cleaned project temp: $ARIA_PROJECT_TEMP"
}

# Clean global temp (rare - only for full reset)
aria_clean_global() {
    rm -rf "$ARIA_GLOBAL_TEMP" "$ARIA_GLOBAL_TEMP_WIN" 2>/dev/null
    echo "Cleaned global temp"
}

# Clean all stale project temps (older than 24h)
aria_clean_stale() {
    local cleaned=0
    for dir in /tmp/aria-????????; do
        [[ ! -d "$dir" ]] && continue
        local created=$(cat "$dir/.created" 2>/dev/null || echo 0)
        local age=$(( $(date +%s) - created ))
        if [[ $age -gt 86400 ]]; then
            rm -rf "$dir"
            ((cleaned++))
        fi
    done
    echo "Cleaned $cleaned stale project temp(s)"
}

# =============================================================================
# PATH HELPERS
# =============================================================================

# Get temp file path (project-scoped by default)
aria_temp_file() {
    local name="${1:-temp}"
    echo "$ARIA_PROJECT_TEMP/$name"
}

# Get Windows-accessible temp file path
aria_temp_file_win() {
    local name="${1:-temp}"
    echo "$ARIA_PROJECT_TEMP_WIN/$name"
}

# Get global temp file path (for cross-agent communication)
aria_global_file() {
    local name="${1:-temp}"
    echo "$ARIA_GLOBAL_TEMP/$name"
}

# =============================================================================
# INFO
# =============================================================================

aria_temp_info() {
    echo "ARIA Temp Directories"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Project: $(pwd)"
    echo "Hash:    $(_aria_project_hash)"
    echo ""
    echo "Project Temp (WSL):     $ARIA_PROJECT_TEMP"
    echo "Project Temp (Windows): $ARIA_PROJECT_TEMP_WIN"
    echo ""
    echo "Global Temp (WSL):      $ARIA_GLOBAL_TEMP"
    echo "Global Temp (Windows):  $ARIA_GLOBAL_TEMP_WIN"
    echo ""
    echo "Usage:"
    echo "  \$(aria_temp_file script.txt)     → project-scoped temp file"
    echo "  \$(aria_temp_file_win script.txt) → Windows-accessible temp file"
    echo "  \$(aria_global_file shared.json)  → global cross-agent file"
}

# CLI when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-info}" in
        info|i)     aria_temp_info ;;
        clean)      aria_clean_project ;;
        clean-all)  aria_clean_global; aria_clean_stale ;;
        stale)      aria_clean_stale ;;
        *)          aria_temp_info ;;
    esac
fi
