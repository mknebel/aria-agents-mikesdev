#!/bin/bash
# ab-metrics.sh - Track A/B test metrics and generate reports
#
# Usage:
#   ab-metrics.sh record /path/to/session  # Record a test result
#   ab-metrics.sh report                    # Show win rates
#   ab-metrics.sh report --model codex      # Filter by model
#   ab-metrics.sh report --last 7d          # Last 7 days

set -e

RESULTS_DIR="$HOME/.claude/ab-results"
METRICS_FILE="$RESULTS_DIR/metrics.json"
mkdir -p "$RESULTS_DIR"

# Initialize metrics file if needed
if [[ ! -f "$METRICS_FILE" ]]; then
    echo '{"tests": [], "summary": {}}' > "$METRICS_FILE"
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ACTION="${1:-report}"
shift || true

case "$ACTION" in
    record)
        SESSION_DIR="$1"
        if [[ -z "$SESSION_DIR" || ! -d "$SESSION_DIR" ]]; then
            echo "Error: Invalid session directory" >&2
            exit 1
        fi

        # Read decision
        DECISION_FILE="$SESSION_DIR/decision.json"
        if [[ ! -f "$DECISION_FILE" ]]; then
            echo "Error: No decision.json found" >&2
            exit 1
        fi

        # Read task info
        TASK_FILE="$SESSION_DIR/task.json"
        TASK=""
        MODELS=""
        if [[ -f "$TASK_FILE" ]]; then
            TASK=$(jq -r '.task' "$TASK_FILE" 2>/dev/null || echo "")
            MODELS=$(jq -r '.models' "$TASK_FILE" 2>/dev/null || echo "")
        fi

        # Extract metrics
        WINNER=$(jq -r '.winner' "$DECISION_FILE")
        STATUS=$(jq -r '.status' "$DECISION_FILE")
        SCORE=$(jq -r '.winner_score' "$DECISION_FILE")
        SIMILARITY=$(jq -r '.avg_similarity' "$DECISION_FILE")
        TIMESTAMP=$(basename "$SESSION_DIR" | cut -d'_' -f1-2)

        # Calculate times from solution files
        TIMES=""
        for timefile in "$SESSION_DIR/solutions"/*.time; do
            if [[ -f "$timefile" ]]; then
                model=$(basename "$timefile" .time)
                time=$(cat "$timefile")
                TIMES="$TIMES\"$model\": $time, "
            fi
        done
        TIMES="{${TIMES%, }}"

        # Add to metrics
        NEW_ENTRY=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "task": "$TASK",
  "models": "$MODELS",
  "winner": "$WINNER",
  "status": "$STATUS",
  "score": $SCORE,
  "similarity": $SIMILARITY,
  "times": $TIMES
}
EOF
)

        # Append to metrics file
        jq ".tests += [$NEW_ENTRY]" "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
        echo "Recorded: $WINNER won ($STATUS, score: $SCORE)"
        ;;

    report|stats)
        # Parse options
        MODEL_FILTER=""
        DAYS_FILTER=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --model|-m) MODEL_FILTER="$2"; shift 2 ;;
                --last|-l) DAYS_FILTER="$2"; shift 2 ;;
                *) shift ;;
            esac
        done

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}A/B Test Metrics Report${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Count totals
        TOTAL=$(jq '.tests | length' "$METRICS_FILE")
        echo -e "Total tests: ${GREEN}$TOTAL${NC}"
        echo ""

        if [[ $TOTAL -eq 0 ]]; then
            echo "No tests recorded yet."
            exit 0
        fi

        # Win rates by model
        echo -e "${YELLOW}Win Rates by Model:${NC}"
        jq -r '.tests | group_by(.winner) | .[] | "\(.[0].winner): \(length)"' "$METRICS_FILE" 2>/dev/null | while read line; do
            model=$(echo "$line" | cut -d: -f1)
            wins=$(echo "$line" | cut -d: -f2 | xargs)
            pct=$((wins * 100 / TOTAL))
            bar=$(printf '%*s' $((pct / 5)) '' | tr ' ' '█')
            echo -e "  $model: $wins wins (${pct}%) $bar"
        done

        echo ""

        # Consensus rate
        CONSENSUS=$(jq '[.tests[] | select(.status == "consensus")] | length' "$METRICS_FILE")
        WEAK=$(jq '[.tests[] | select(.status == "weak_consensus")] | length' "$METRICS_FILE")
        CONFLICT=$(jq '[.tests[] | select(.status == "conflict")] | length' "$METRICS_FILE")

        echo -e "${YELLOW}Decision Distribution:${NC}"
        echo -e "  Consensus: ${GREEN}$CONSENSUS${NC} ($(( CONSENSUS * 100 / TOTAL ))%)"
        echo -e "  Weak consensus: ${YELLOW}$WEAK${NC} ($(( WEAK * 100 / TOTAL ))%)"
        echo -e "  Conflict: ${RED}$CONFLICT${NC} ($(( CONFLICT * 100 / TOTAL ))%)"

        echo ""

        # Average scores
        AVG_SCORE=$(jq '[.tests[].score] | add / length | floor' "$METRICS_FILE")
        AVG_SIMILARITY=$(jq '[.tests[].similarity] | add / length | floor' "$METRICS_FILE")

        echo -e "${YELLOW}Averages:${NC}"
        echo -e "  Winner score: $AVG_SCORE"
        echo -e "  Similarity: ${AVG_SIMILARITY}%"

        echo ""

        # Recent tests
        echo -e "${YELLOW}Recent Tests:${NC}"
        jq -r '.tests | .[-5:] | reverse | .[] | "  \(.timestamp): \(.winner) (\(.status))"' "$METRICS_FILE" 2>/dev/null || echo "  (none)"
        ;;

    clear)
        echo '{"tests": [], "summary": {}}' > "$METRICS_FILE"
        echo "Metrics cleared"
        ;;

    *)
        cat << 'HELP'
ab-metrics.sh - A/B Test Metrics

Usage:
  ab-metrics.sh record /path/to/session   Record test result
  ab-metrics.sh report                    Show metrics report
  ab-metrics.sh report --model codex      Filter by model
  ab-metrics.sh clear                     Clear all metrics

Examples:
  ab-metrics.sh report
  ab-metrics.sh report --last 7d
HELP
        ;;
esac
