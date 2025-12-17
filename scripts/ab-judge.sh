#!/bin/bash
# ab-judge.sh - Evaluate and compare A/B test solutions
# Determines consensus, scores solutions, picks winner
#
# Usage:
#   ab-judge.sh /path/to/session_dir
#
# Output: CONSENSUS or CONFLICT with winner/scores

set -e

SESSION_DIR="$1"
if [[ -z "$SESSION_DIR" || ! -d "$SESSION_DIR/solutions" ]]; then
    echo "Error: Invalid session directory" >&2
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SOLUTIONS_DIR="$SESSION_DIR/solutions"
REVIEWS_DIR="$SESSION_DIR/reviews"
mkdir -p "$REVIEWS_DIR"

# Get all solution files
SOLUTIONS=($(ls "$SOLUTIONS_DIR"/*.txt 2>/dev/null | xargs -I{} basename {} .txt))

if [[ ${#SOLUTIONS[@]} -lt 2 ]]; then
    echo -e "${YELLOW}Only ${#SOLUTIONS[@]} solution(s) - skipping comparison${NC}"
    if [[ ${#SOLUTIONS[@]} -eq 1 ]]; then
        echo "WINNER: ${SOLUTIONS[0]}"
    fi
    exit 0
fi

echo -e "${BLUE}Judging ${#SOLUTIONS[@]} solutions...${NC}"

# Initialize scores
declare -A SCORES
declare -A LENGTHS
declare -A CODE_BLOCKS

for sol in "${SOLUTIONS[@]}"; do
    SCORES[$sol]=0
    FILE="$SOLUTIONS_DIR/${sol}.txt"
    LENGTHS[$sol]=$(wc -c < "$FILE")

    # Count code blocks (indicates actual code vs just explanation)
    CODE_BLOCKS[$sol]=$(grep -c '```' "$FILE" 2>/dev/null | tr -d '\n' || echo 0)
done

# Scoring criteria

# 1. Has code blocks (actual implementation vs just explanation)
echo -e "\n${CYAN}1. Code blocks check${NC}"
for sol in "${SOLUTIONS[@]}"; do
    blocks=${CODE_BLOCKS[$sol]}
    if [[ $blocks -ge 2 ]]; then
        SCORES[$sol]=$((SCORES[$sol] + 30))
        echo -e "  ${GREEN}✓${NC} $sol: $blocks blocks (+30)"
    elif [[ $blocks -ge 1 ]]; then
        SCORES[$sol]=$((SCORES[$sol] + 15))
        echo -e "  ${YELLOW}~${NC} $sol: $blocks block (+15)"
    else
        echo -e "  ${RED}✗${NC} $sol: no code blocks (+0)"
    fi
done

# 2. Reasonable length (not too short, not too verbose)
echo -e "\n${CYAN}2. Length check${NC}"
for sol in "${SOLUTIONS[@]}"; do
    len=${LENGTHS[$sol]}
    if [[ $len -gt 500 && $len -lt 10000 ]]; then
        SCORES[$sol]=$((SCORES[$sol] + 20))
        echo -e "  ${GREEN}✓${NC} $sol: ${len}b (good length +20)"
    elif [[ $len -gt 200 && $len -lt 20000 ]]; then
        SCORES[$sol]=$((SCORES[$sol] + 10))
        echo -e "  ${YELLOW}~${NC} $sol: ${len}b (ok length +10)"
    else
        echo -e "  ${RED}✗${NC} $sol: ${len}b (too short/long +0)"
    fi
done

# 3. Contains common code patterns (function, class, return, etc)
echo -e "\n${CYAN}3. Code patterns check${NC}"
for sol in "${SOLUTIONS[@]}"; do
    FILE="$SOLUTIONS_DIR/${sol}.txt"
    PATTERN_SCORE=0

    # Check for function/method definitions
    if grep -qE '(function |def |public |private |protected |async )' "$FILE" 2>/dev/null; then
        PATTERN_SCORE=$((PATTERN_SCORE + 10))
    fi

    # Check for control structures
    if grep -qE '(if |for |while |switch |try |catch )' "$FILE" 2>/dev/null; then
        PATTERN_SCORE=$((PATTERN_SCORE + 10))
    fi

    # Check for return statements
    if grep -qE '(return |yield |throw )' "$FILE" 2>/dev/null; then
        PATTERN_SCORE=$((PATTERN_SCORE + 5))
    fi

    # Check for common web patterns (relevant to LaunchYourKid)
    if grep -qiE '(validate|sanitize|escape|query|model|controller)' "$FILE" 2>/dev/null; then
        PATTERN_SCORE=$((PATTERN_SCORE + 5))
    fi

    SCORES[$sol]=$((SCORES[$sol] + PATTERN_SCORE))
    echo -e "  $sol: +$PATTERN_SCORE (patterns)"
done

# 4. No obvious errors
echo -e "\n${CYAN}4. Error check${NC}"
for sol in "${SOLUTIONS[@]}"; do
    FILE="$SOLUTIONS_DIR/${sol}.txt"

    # Check for error messages in output
    if grep -qiE '(error:|exception:|failed|cannot|unable to)' "$FILE" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} $sol: contains error messages (-10)"
        SCORES[$sol]=$((SCORES[$sol] - 10))
    else
        SCORES[$sol]=$((SCORES[$sol] + 10))
        echo -e "  ${GREEN}✓${NC} $sol: no errors (+10)"
    fi
done

# 5. Similarity check (for consensus detection)
echo -e "\n${CYAN}5. Similarity analysis${NC}"

# Extract just the code blocks for comparison
extract_code() {
    local file="$1"
    grep -A 1000 '```' "$file" 2>/dev/null | grep -B 1000 '```' | grep -v '```' || cat "$file"
}

SIMILARITY_SCORES=()
TOTAL_COMPARISONS=0
HIGH_SIMILARITY_COUNT=0

for ((i=0; i<${#SOLUTIONS[@]}; i++)); do
    for ((j=i+1; j<${#SOLUTIONS[@]}; j++)); do
        FILE1="$SOLUTIONS_DIR/${SOLUTIONS[$i]}.txt"
        FILE2="$SOLUTIONS_DIR/${SOLUTIONS[$j]}.txt"

        # Simple similarity: count common lines
        COMMON=$(comm -12 <(extract_code "$FILE1" | sort -u) <(extract_code "$FILE2" | sort -u) | wc -l)
        TOTAL1=$(extract_code "$FILE1" | sort -u | wc -l)
        TOTAL2=$(extract_code "$FILE2" | sort -u | wc -l)
        MAX_LINES=$((TOTAL1 > TOTAL2 ? TOTAL1 : TOTAL2))

        if [[ $MAX_LINES -gt 0 ]]; then
            SIMILARITY=$((COMMON * 100 / MAX_LINES))
        else
            SIMILARITY=0
        fi

        echo -e "  ${SOLUTIONS[$i]} vs ${SOLUTIONS[$j]}: ${SIMILARITY}% similar"
        SIMILARITY_SCORES+=($SIMILARITY)
        TOTAL_COMPARISONS=$((TOTAL_COMPARISONS + 1))

        if [[ $SIMILARITY -ge 50 ]]; then
            HIGH_SIMILARITY_COUNT=$((HIGH_SIMILARITY_COUNT + 1))
        fi
    done
done

# Determine consensus
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Find winner (highest score)
WINNER=""
WINNER_SCORE=0
for sol in "${SOLUTIONS[@]}"; do
    echo -e "Final score: $sol = ${SCORES[$sol]}"
    if [[ ${SCORES[$sol]} -gt $WINNER_SCORE ]]; then
        WINNER_SCORE=${SCORES[$sol]}
        WINNER=$sol
    fi
done

# Calculate average similarity
if [[ $TOTAL_COMPARISONS -gt 0 ]]; then
    SUM=0
    for s in "${SIMILARITY_SCORES[@]}"; do
        SUM=$((SUM + s))
    done
    AVG_SIMILARITY=$((SUM / TOTAL_COMPARISONS))
else
    AVG_SIMILARITY=0
fi

echo ""

# Decision
if [[ $AVG_SIMILARITY -ge 40 && $WINNER_SCORE -ge 50 ]]; then
    echo -e "${GREEN}CONSENSUS${NC} - Solutions agree (${AVG_SIMILARITY}% avg similarity)"
    echo -e "WINNER: ${GREEN}$WINNER${NC} (score: $WINNER_SCORE)"

    # Save decision
    cat > "$SESSION_DIR/decision.json" << EOF
{
  "status": "consensus",
  "winner": "$WINNER",
  "winner_score": $WINNER_SCORE,
  "avg_similarity": $AVG_SIMILARITY,
  "solutions": ${#SOLUTIONS[@]},
  "auto_apply_safe": true
}
EOF

elif [[ $WINNER_SCORE -ge 60 ]]; then
    echo -e "${YELLOW}WEAK CONSENSUS${NC} - Clear winner but solutions differ"
    echo -e "WINNER: ${YELLOW}$WINNER${NC} (score: $WINNER_SCORE)"
    echo -e "Review recommended before applying"

    cat > "$SESSION_DIR/decision.json" << EOF
{
  "status": "weak_consensus",
  "winner": "$WINNER",
  "winner_score": $WINNER_SCORE,
  "avg_similarity": $AVG_SIMILARITY,
  "solutions": ${#SOLUTIONS[@]},
  "auto_apply_safe": false
}
EOF

else
    echo -e "${RED}CONFLICT${NC} - Solutions diverge significantly"
    echo -e "Best candidate: ${RED}$WINNER${NC} (score: $WINNER_SCORE)"
    echo -e "Manual review required"

    cat > "$SESSION_DIR/decision.json" << EOF
{
  "status": "conflict",
  "winner": "$WINNER",
  "winner_score": $WINNER_SCORE,
  "avg_similarity": $AVG_SIMILARITY,
  "solutions": ${#SOLUTIONS[@]},
  "auto_apply_safe": false
}
EOF
fi

# Save scores
echo "{" > "$REVIEWS_DIR/scores.json"
first=true
for sol in "${SOLUTIONS[@]}"; do
    if $first; then first=false; else echo "," >> "$REVIEWS_DIR/scores.json"; fi
    echo "  \"$sol\": ${SCORES[$sol]}" >> "$REVIEWS_DIR/scores.json"
done
echo "}" >> "$REVIEWS_DIR/scores.json"
