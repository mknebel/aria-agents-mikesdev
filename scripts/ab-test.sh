#!/bin/bash
# ab-test.sh - A/B Testing for Code Generation
# Runs multiple models in parallel, compares results, picks winner
#
# Usage:
#   ab-test.sh "implement login endpoint"
#   ab-test.sh "add validation" --models "codex,gemini"
#   ab-test.sh "refactor auth" --auto  # auto-apply winner
#
# Output: Winner solution or conflict for Claude review

set -e

SCRIPTS_DIR="$HOME/.claude/scripts"
CONFIG_FILE="$HOME/.claude/ab-config.json"
RESULTS_DIR="$HOME/.claude/ab-results"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR" "$RESULTS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
DEFAULT_MODELS="codex,gemini,fast"
AUTO_APPLY=false
CONTEXT=""
TASK=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --models|-m) MODELS="$2"; shift 2 ;;
        --auto|-a) AUTO_APPLY=true; shift ;;
        --context|-c) CONTEXT="$2"; shift 2 ;;
        --help|-h)
            cat << 'HELP'
ab-test.sh - A/B Code Generation Testing

Usage: ab-test.sh "task description" [options]

Options:
  --models, -m    Comma-separated models (default: codex,gemini,fast)
  --auto, -a      Auto-apply winner if consensus
  --context, -c   Additional context to include

Models available:
  codex    - OpenAI Codex (your GPT subscription)
  gemini   - Google Gemini (your Google subscription)
  fast     - DeepSeek via OpenRouter (cheap/fast)
  tools    - Qwen Coder via OpenRouter

Examples:
  ab-test.sh "add password reset endpoint"
  ab-test.sh "implement rate limiting" --models "codex,gemini"
  ab-test.sh "refactor auth" --auto --context "uses JWT"
HELP
            exit 0
            ;;
        *) TASK="$TASK $1"; shift ;;
    esac
done

TASK=$(echo "$TASK" | xargs)
MODELS="${MODELS:-$DEFAULT_MODELS}"

if [[ -z "$TASK" ]]; then
    echo -e "${RED}Error: No task provided${NC}" >&2
    echo "Usage: ab-test.sh \"task description\"" >&2
    exit 1
fi

# Generate session ID
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TASK_HASH=$(echo "$TASK" | md5sum | cut -c1-8)
SESSION_ID="${TIMESTAMP}_${TASK_HASH}"
SESSION_DIR="$RESULTS_DIR/$SESSION_ID"
mkdir -p "$SESSION_DIR/solutions" "$SESSION_DIR/reviews"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}A/B Code Test${NC} | Session: $SESSION_ID"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Task: ${YELLOW}$TASK${NC}"
echo -e "Models: ${GREEN}$MODELS${NC}"
echo ""

# Prepare prompt with context
FULL_PROMPT="$TASK"
if [[ -n "$CONTEXT" ]]; then
    FULL_PROMPT="Context: $CONTEXT

Task: $TASK"
fi

# Save task info
cat > "$SESSION_DIR/task.json" << EOF
{
  "task": "$TASK",
  "context": "$CONTEXT",
  "models": "$MODELS",
  "timestamp": "$TIMESTAMP",
  "auto_apply": $AUTO_APPLY
}
EOF

# Run models in parallel
echo -e "${YELLOW}Running models in parallel...${NC}"
echo ""

IFS=',' read -ra MODEL_ARRAY <<< "$MODELS"
PIDS=()
MODEL_NAMES=()

for model in "${MODEL_ARRAY[@]}"; do
    model=$(echo "$model" | xargs)  # trim whitespace
    MODEL_NAMES+=("$model")
    OUTPUT_FILE="$SESSION_DIR/solutions/${model}.txt"
    TIME_FILE="$SESSION_DIR/solutions/${model}.time"

    (
        START=$(date +%s.%N)
        case "$model" in
            codex|c)
                codex "$FULL_PROMPT" > "$OUTPUT_FILE" 2>&1
                ;;
            gemini|g)
                gemini "$FULL_PROMPT" > "$OUTPUT_FILE" 2>&1
                ;;
            fast|f)
                KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
                curl -s https://openrouter.ai/api/v1/chat/completions \
                    -H "Authorization: Bearer $KEY" \
                    -H "Content-Type: application/json" \
                    -d "{
                        \"model\": \"@preset/super-fast\",
                        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$FULL_PROMPT" | jq -Rs .)}],
                        \"max_tokens\": 8000
                    }" | jq -r '.choices[0].message.content // .error.message' > "$OUTPUT_FILE"
                ;;
            tools|t)
                KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
                curl -s https://openrouter.ai/api/v1/chat/completions \
                    -H "Authorization: Bearer $KEY" \
                    -H "Content-Type: application/json" \
                    -d "{
                        \"model\": \"@preset/general-non-browser-tools\",
                        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$FULL_PROMPT" | jq -Rs .)}],
                        \"max_tokens\": 8000
                    }" | jq -r '.choices[0].message.content // .error.message' > "$OUTPUT_FILE"
                ;;
            *)
                echo "Unknown model: $model" > "$OUTPUT_FILE"
                ;;
        esac
        END=$(date +%s.%N)
        echo "scale=2; $END - $START" | bc > "$TIME_FILE"
    ) &
    PIDS+=($!)
done

# Wait for all models
for i in "${!PIDS[@]}"; do
    wait "${PIDS[$i]}" 2>/dev/null || true
    model="${MODEL_NAMES[$i]}"
    TIME_FILE="$SESSION_DIR/solutions/${model}.time"
    OUTPUT_FILE="$SESSION_DIR/solutions/${model}.txt"

    if [[ -f "$TIME_FILE" ]]; then
        TIME=$(cat "$TIME_FILE")
        SIZE=$(wc -c < "$OUTPUT_FILE" 2>/dev/null || echo "0")
        echo -e "  ${GREEN}✓${NC} $model: ${TIME}s, ${SIZE} bytes"
    else
        echo -e "  ${RED}✗${NC} $model: failed"
    fi
done

echo ""

# Call judge to evaluate
echo -e "${YELLOW}Evaluating solutions...${NC}"
if [[ -x "$SCRIPTS_DIR/ab-judge.sh" ]]; then
    JUDGE_RESULT=$("$SCRIPTS_DIR/ab-judge.sh" "$SESSION_DIR")
    echo "$JUDGE_RESULT"

    # Parse judge result
    WINNER=$(echo "$JUDGE_RESULT" | grep -oP 'WINNER:\s*\K\w+' || echo "")
    CONSENSUS=$(echo "$JUDGE_RESULT" | grep -q "CONSENSUS" && echo "true" || echo "false")

    if [[ -n "$WINNER" ]]; then
        WINNER_FILE="$SESSION_DIR/solutions/${WINNER}.txt"
        if [[ -f "$WINNER_FILE" ]]; then
            cp "$WINNER_FILE" "$VAR_DIR/ab_winner"
            echo -e "\n${GREEN}Winner saved to \$ab_winner${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Judge not available - manual review required${NC}"
    CONSENSUS="false"
    WINNER=""
fi

# Save all solutions to var files for easy access
for model in "${MODEL_NAMES[@]}"; do
    OUTPUT_FILE="$SESSION_DIR/solutions/${model}.txt"
    if [[ -f "$OUTPUT_FILE" ]]; then
        cp "$OUTPUT_FILE" "$VAR_DIR/ab_${model}"
    fi
done

# Summary
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Results${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Session: $SESSION_DIR"
echo -e "Solutions: \$ab_codex, \$ab_gemini, \$ab_fast"
if [[ -n "$WINNER" ]]; then
    echo -e "Winner: ${GREEN}\$ab_winner${NC} ($WINNER)"
fi

# Auto-apply if consensus and --auto flag
if [[ "$AUTO_APPLY" == "true" && "$CONSENSUS" == "true" && -n "$WINNER" ]]; then
    echo ""
    echo -e "${YELLOW}Auto-applying winner...${NC}"
    if [[ -x "$SCRIPTS_DIR/ab-apply.sh" ]]; then
        "$SCRIPTS_DIR/ab-apply.sh" "$SESSION_DIR" "$WINNER"
    else
        echo -e "${YELLOW}ab-apply.sh not available - skipping auto-apply${NC}"
    fi
fi

# Record metrics
if [[ -x "$SCRIPTS_DIR/ab-metrics.sh" ]]; then
    "$SCRIPTS_DIR/ab-metrics.sh" record "$SESSION_DIR" >/dev/null 2>&1 &
fi

echo ""
echo -e "View solutions: cat \$ab_codex | cat \$ab_gemini | cat \$ab_fast"
