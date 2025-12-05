#!/bin/bash
# ARIA Efficiency Scoring - Gemini-style reporting
# Beautiful terminal output with detailed metrics

source ~/.claude/scripts/aria-state.sh 2>/dev/null

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

aria_calculate_score() {
    local reads=$(aria_get reads)
    local writes=$(aria_get writes)
    local greps=$(aria_get greps)
    local tasks=$(aria_get tasks)
    local external=$(aria_get external)
    local cache_hits=$(aria_get cache_hits)
    local cache_misses=$(aria_get cache_misses)

    local total_ops=$((reads + writes + greps))
    [[ $total_ops -eq 0 ]] && { echo "A|100|0"; return; }

    # External calls worth 3x (they save Claude tokens)
    local weighted_external=$((external * 3))
    local efficiency=$((weighted_external * 100 / (total_ops + weighted_external + 1)))

    # Cache bonus
    local total_cache=$((cache_hits + cache_misses))
    if [[ $total_cache -gt 0 ]]; then
        local cache_rate=$((cache_hits * 100 / total_cache))
        efficiency=$((efficiency + cache_rate / 10))
    fi

    # Cap at 100
    [[ $efficiency -gt 100 ]] && efficiency=100

    local grade
    [[ $efficiency -ge 50 ]] && grade="A"
    [[ $efficiency -ge 35 && $efficiency -lt 50 ]] && grade="B"
    [[ $efficiency -ge 20 && $efficiency -lt 35 ]] && grade="C"
    [[ $efficiency -lt 20 ]] && grade="D"

    echo "${grade}|${efficiency}|${total_ops}"
}

aria_show_summary() {
    local started=$(aria_get started)
    local now=$(date +%s)
    local duration=$((now - started))
    local mins=$((duration / 60))
    local secs=$((duration % 60))

    local session_id=$(aria_get session_id)
    local reads=$(aria_get reads)
    local writes=$(aria_get writes)
    local greps=$(aria_get greps)
    local tasks=$(aria_get tasks)
    local external=$(aria_get external)
    local tool_calls=$(aria_get tool_calls)
    local tool_success=$(aria_get tool_success)
    local tool_fail=$(aria_get tool_fail)
    local cache_hits=$(aria_get cache_hits)
    local cache_misses=$(aria_get cache_misses)

    # Calculate success rate
    local success_rate=0
    [[ $tool_calls -gt 0 ]] && success_rate=$((tool_success * 100 / tool_calls))

    # Calculate cache savings
    local total_cache=$((cache_hits + cache_misses))
    local cache_pct=0
    [[ $total_cache -gt 0 ]] && cache_pct=$((cache_hits * 100 / total_cache))

    # Get score
    local result=$(aria_calculate_score)
    local grade=$(echo "$result" | cut -d'|' -f1)
    local efficiency=$(echo "$result" | cut -d'|' -f2)

    # Grade color
    local grade_color=$GREEN
    case $grade in
        B) grade_color=$YELLOW ;;
        C) grade_color=$MAGENTA ;;
        D) grade_color=$RED ;;
    esac

    # Box drawing
    echo ""
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│${RESET}                                                                             ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${WHITE}ARIA Session Summary${RESET}                                                       ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  Session ID:              ${DIM}${session_id}${RESET}                                        ${CYAN}│${RESET}"
    printf "${CYAN}│${RESET}  Efficiency Grade:        ${grade_color}%s${RESET} (%d%%)                                          ${CYAN}│${RESET}\n" "$grade" "$efficiency"
    echo -e "${CYAN}│${RESET}                                                                             ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${WHITE}Operations${RESET}                                                                  ${CYAN}│${RESET}"
    printf "${CYAN}│${RESET}  Tool Calls:              %-4d ( ${GREEN}✓ %-3d${RESET} ${RED}✗ %-3d${RESET} )                           ${CYAN}│${RESET}\n" "$tool_calls" "$tool_success" "$tool_fail"
    printf "${CYAN}│${RESET}  Success Rate:            %.1f%%                                              ${CYAN}│${RESET}\n" "$success_rate"
    printf "${CYAN}│${RESET}  Reads: %-3d  Writes: %-3d  Greps: %-3d  Tasks: %-3d                          ${CYAN}│${RESET}\n" "$reads" "$writes" "$greps" "$tasks"
    printf "${CYAN}│${RESET}  External Tools:          ${GREEN}%-4d${RESET} (ctx/gemini/codex)                           ${CYAN}│${RESET}\n" "$external"
    echo -e "${CYAN}│${RESET}                                                                             ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${WHITE}Performance${RESET}                                                                ${CYAN}│${RESET}"
    printf "${CYAN}│${RESET}  Wall Time:               %dm %ds                                            ${CYAN}│${RESET}\n" "$mins" "$secs"
    echo -e "${CYAN}│${RESET}                                                                             ${CYAN}│${RESET}"

    # Model usage table
    echo -e "${CYAN}│${RESET}  ${WHITE}Model Usage${RESET}               ${DIM}Calls${RESET}                                          ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ─────────────────────────────────                                          ${CYAN}│${RESET}"

    local claude_opus=$(jq -r '.models.claude_opus // 0' "$ARIA_STATE" 2>/dev/null)
    local claude_haiku=$(jq -r '.models.claude_haiku // 0' "$ARIA_STATE" 2>/dev/null)
    local codex_max=$(jq -r '.models.codex_max // 0' "$ARIA_STATE" 2>/dev/null)
    local codex_mini=$(jq -r '.models.codex_mini // 0' "$ARIA_STATE" 2>/dev/null)
    local o3=$(jq -r '.models.o3 // 0' "$ARIA_STATE" 2>/dev/null)
    local o4_mini=$(jq -r '.models.o4_mini // 0' "$ARIA_STATE" 2>/dev/null)
    local gemini=$(jq -r '.models.gemini // 0' "$ARIA_STATE" 2>/dev/null)
    local gemini_flash=$(jq -r '.models.gemini_flash // 0' "$ARIA_STATE" 2>/dev/null)

    [[ $claude_opus -gt 0 ]] && printf "${CYAN}│${RESET}  ${MAGENTA}claude-opus${RESET}               %4d                                          ${CYAN}│${RESET}\n" "$claude_opus"
    [[ $claude_haiku -gt 0 ]] && printf "${CYAN}│${RESET}  ${BLUE}claude-haiku${RESET}              %4d                                          ${CYAN}│${RESET}\n" "$claude_haiku"
    [[ $codex_max -gt 0 ]] && printf "${CYAN}│${RESET}  ${YELLOW}gpt-5.1-codex-max${RESET}         %4d                                          ${CYAN}│${RESET}\n" "$codex_max"
    [[ $codex_mini -gt 0 ]] && printf "${CYAN}│${RESET}  ${DIM}gpt-5.1-codex-mini${RESET}        %4d                                          ${CYAN}│${RESET}\n" "$codex_mini"
    [[ $o3 -gt 0 ]] && printf "${CYAN}│${RESET}  ${WHITE}o3${RESET}                        %4d                                          ${CYAN}│${RESET}\n" "$o3"
    [[ $o4_mini -gt 0 ]] && printf "${CYAN}│${RESET}  ${DIM}o4-mini${RESET}                   %4d                                          ${CYAN}│${RESET}\n" "$o4_mini"
    [[ $gemini -gt 0 ]] && printf "${CYAN}│${RESET}  ${GREEN}gemini (FREE)${RESET}             %4d                                          ${CYAN}│${RESET}\n" "$gemini"
    [[ $gemini_flash -gt 0 ]] && printf "${CYAN}│${RESET}  ${GREEN}gemini-flash (FREE)${RESET}       %4d                                          ${CYAN}│${RESET}\n" "$gemini_flash"

    echo -e "${CYAN}│${RESET}                                                                             ${CYAN}│${RESET}"

    # Cache savings highlight
    if [[ $total_cache -gt 0 && $cache_pct -gt 0 ]]; then
        echo -e "${CYAN}│${RESET}  ${GREEN}Savings:${RESET} ${cache_hits} (${cache_pct}%) of file reads served from cache                    ${CYAN}│${RESET}"
        echo -e "${CYAN}│${RESET}                                                                             ${CYAN}│${RESET}"
    fi

    # Tips based on grade
    case $grade in
        D)
            echo -e "${CYAN}│${RESET}  ${YELLOW}» Tip:${RESET} Use 'ctx' or 'gemini @.' before multiple reads                     ${CYAN}│${RESET}"
            ;;
        C)
            echo -e "${CYAN}│${RESET}  ${YELLOW}» Tip:${RESET} Try 'codex exec' for code generation tasks                         ${CYAN}│${RESET}"
            ;;
        B)
            echo -e "${CYAN}│${RESET}  ${GREEN}» Good:${RESET} Using external tools. Try caching more reads                       ${CYAN}│${RESET}"
            ;;
        A)
            echo -e "${CYAN}│${RESET}  ${GREEN}» Excellent:${RESET} Optimal external-first workflow                               ${CYAN}│${RESET}"
            ;;
    esac

    echo -e "${CYAN}│${RESET}                                                                             ${CYAN}│${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""
}

aria_show_compact() {
    local result=$(aria_calculate_score)
    local grade=$(echo "$result" | cut -d'|' -f1)
    local efficiency=$(echo "$result" | cut -d'|' -f2)
    local ops=$(echo "$result" | cut -d'|' -f3)
    local external=$(aria_get external)

    local grade_color=$GREEN
    case $grade in
        B) grade_color=$YELLOW ;;
        C) grade_color=$MAGENTA ;;
        D) grade_color=$RED ;;
    esac

    echo -e "${grade_color}[ARIA ${grade}]${RESET} ${efficiency}% efficient | Ops: ${ops} | External: ${external}"
}

# CLI interface - only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-summary}" in
        summary|s)
            aria_show_summary
            ;;
        compact|c)
            aria_show_compact
            ;;
        raw|r)
            jq . "$ARIA_STATE" 2>/dev/null || echo "No session"
            ;;
        grade|g)
            aria_calculate_score | cut -d'|' -f1
            ;;
        *)
            aria_show_summary
            ;;
    esac
fi
