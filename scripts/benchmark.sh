#!/bin/bash
# benchmark.sh - Measure LLM and tool performance
#
# Usage:
#   benchmark.sh           # Run all benchmarks
#   benchmark.sh quick     # Quick test (1 iteration)
#   benchmark.sh llm       # LLM providers only
#   benchmark.sh ctx       # Context search only
#
# Output saved to ~/.claude/benchmarks/YYYY-MM-DD.json

set -e

SCRIPTS_DIR="$HOME/.claude/scripts"
BENCH_DIR="$HOME/.claude/benchmarks"
mkdir -p "$BENCH_DIR"

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)
OUTPUT_FILE="$BENCH_DIR/${DATE}.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

MODE="${1:-all}"
ITERATIONS=3
[[ "$MODE" == "quick" ]] && ITERATIONS=1

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  Claude Code Benchmark - $DATE $TIME${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Timing function
measure() {
    local start end duration
    start=$(date +%s.%N)
    "$@" >/dev/null 2>&1
    end=$(date +%s.%N)
    duration=$(echo "$end - $start" | bc)
    echo "$duration"
}

# Average of multiple runs
average() {
    local cmd="$1"
    local total=0
    for ((i=1; i<=ITERATIONS; i++)); do
        local t=$(measure bash -c "$cmd")
        total=$(echo "$total + $t" | bc)
    done
    echo "scale=3; $total / $ITERATIONS" | bc
}

results=()
add_result() {
    local name="$1"
    local time="$2"
    local unit="${3:-s}"
    results+=("\"$name\": $time")
    printf "  %-30s %6.3f%s\n" "$name" "$time" "$unit"
}

# LLM Benchmarks
if [[ "$MODE" == "all" || "$MODE" == "llm" || "$MODE" == "quick" ]]; then
    echo -e "${GREEN}▶ LLM Response Times${NC}"

    # Clear cache for fair test
    rm -rf /tmp/claude_vars/cache/* 2>/dev/null || true

    # Fast (DeepSeek)
    t=$(average "$SCRIPTS_DIR/ai.sh fast 'say hello' 2>/dev/null")
    add_result "llm_fast_simple" "$t"

    # Codex
    if command -v codex &>/dev/null; then
        t=$(average "codex 'say hello' 2>/dev/null")
        add_result "llm_codex_simple" "$t"
    fi

    # Cache hit test
    $SCRIPTS_DIR/llm.sh fast "benchmark test query" >/dev/null 2>&1
    t=$(measure $SCRIPTS_DIR/llm.sh fast "benchmark test query")
    add_result "llm_cache_hit" "$t"

    echo ""
fi

# Context Search Benchmarks
if [[ "$MODE" == "all" || "$MODE" == "ctx" || "$MODE" == "quick" ]]; then
    echo -e "${GREEN}▶ Context Search Times${NC}"

    # Need a project directory
    PROJECT="/mnt/d/MikesDev/www/LaunchYourKid/LaunchYourKid-Cake4/register"
    if [[ -d "$PROJECT" ]]; then
        cd "$PROJECT"

        # Fast search (ripgrep)
        t=$(average "$SCRIPTS_DIR/ctx.sh -f 'function' --no-save 2>/dev/null")
        add_result "ctx_fast_ripgrep" "$t"

        # Semantic search
        t=$(average "$SCRIPTS_DIR/ctx.sh -s 'payment' --no-save 2>/dev/null")
        add_result "ctx_semantic_indexed" "$t"
    fi

    echo ""
fi

# Variable Operations
if [[ "$MODE" == "all" || "$MODE" == "quick" ]]; then
    echo -e "${GREEN}▶ Variable Operations${NC}"

    # Save
    t=$(average "echo 'test data' | $SCRIPTS_DIR/var.sh save bench_test - 'test'")
    add_result "var_save" "$t"

    # Get
    t=$(average "$SCRIPTS_DIR/var.sh get bench_test")
    add_result "var_get" "$t"

    # List
    t=$(average "$SCRIPTS_DIR/var.sh list")
    add_result "var_list" "$t"

    # Cleanup
    rm -f /tmp/claude_vars/bench_test.* 2>/dev/null

    echo ""
fi

# Hook Performance
if [[ "$MODE" == "all" || "$MODE" == "quick" ]]; then
    echo -e "${GREEN}▶ Hook Execution${NC}"

    HOOKS_DIR="$HOME/.claude/hooks"
    if [[ -d "$HOOKS_DIR" ]]; then
        for hook in "$HOOKS_DIR"/*.sh; do
            [[ -f "$hook" ]] || continue
            name=$(basename "$hook" .sh)
            # Simulate hook input
            t=$(measure bash -c "echo '{\"cwd\":\"/tmp\",\"session_id\":\"test\"}' | $hook 2>/dev/null || true")
            t_ms=$(echo "$t * 1000" | bc)
            add_result "hook_$name" "$t_ms" "ms"
        done
    fi

    echo ""
fi

# System Info
echo -e "${GREEN}▶ System Info${NC}"
echo "  Date: $DATE $TIME"
echo "  Iterations: $ITERATIONS"
if command -v codex &>/dev/null; then
    echo "  Codex: $(codex --version 2>/dev/null || echo 'available')"
fi

# Save JSON
{
    echo "{"
    echo "  \"date\": \"$DATE\","
    echo "  \"time\": \"$TIME\","
    echo "  \"iterations\": $ITERATIONS,"
    echo "  \"results\": {"
    IFS=','
    echo "    ${results[*]}"
    echo "  }"
    echo "}"
} > "$OUTPUT_FILE"

echo ""
echo -e "${CYAN}Results saved: $OUTPUT_FILE${NC}"

# Compare with previous if exists
PREV=$(ls -1 "$BENCH_DIR"/*.json 2>/dev/null | grep -v "$DATE" | tail -1 || true)
if [[ -f "$PREV" ]]; then
    echo ""
    echo -e "${YELLOW}▶ Comparison with $(basename "$PREV" .json)${NC}"
    # Simple comparison - show if faster/slower
    for key in llm_fast_simple ctx_fast_ripgrep; do
        curr=$(grep "\"$key\"" "$OUTPUT_FILE" | grep -oP '[\d.]+' | head -1 || echo "0")
        prev=$(grep "\"$key\"" "$PREV" | grep -oP '[\d.]+' | head -1 || echo "0")
        if [[ -n "$curr" && -n "$prev" && "$prev" != "0" ]]; then
            diff=$(echo "scale=1; (($prev - $curr) / $prev) * 100" | bc 2>/dev/null || echo "0")
            if (( $(echo "$diff > 0" | bc -l) )); then
                printf "  %-25s %+.1f%% faster\n" "$key" "$diff"
            elif (( $(echo "$diff < 0" | bc -l) )); then
                printf "  %-25s %.1f%% slower\n" "$key" "${diff#-}"
            else
                printf "  %-25s no change\n" "$key"
            fi
        fi
    done
fi
