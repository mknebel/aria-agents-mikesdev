#!/bin/bash
# Browser Agent - Agentic browser automation
# Orchestrates OpenRouter browser preset with Playwright
#
# Usage:
#   browser-agent.sh "test login flow on http://localhost/app"
#   browser-agent.sh visible "verify homepage loads correctly"

set -e

MAX_ITERATIONS=20
OPENROUTER_KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
# DeepSeek is fast and cheap
MODEL="deepseek/deepseek-chat"
VAR_DIR="/tmp/claude_vars"
LOG_FILE="$VAR_DIR/browser-agent.log"
SCREENSHOT_DIR="$HOME/.claude/browser-screenshots"

mkdir -p "$VAR_DIR" "$SCREENSHOT_DIR"

# Parse mode
HEADLESS="true"
if [ "$1" = "visible" ]; then
    HEADLESS="false"
    shift
fi

TASK="$*"
[ -z "$TASK" ] && echo "Usage: browser-agent.sh [visible] \"task\"" && exit 1
[ -z "$OPENROUTER_KEY" ] && echo "Error: No OpenRouter API key" && exit 1

echo "=== Browser Agent ===" > "$LOG_FILE"
echo "Task: $TASK" >> "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"

# System prompt
SYSTEM_PROMPT='Browser automation agent. Execute ALL steps in the user task.

ACTIONS (one per response, raw JSON only):
{"action":"navigate","url":"URL"}
{"action":"screenshot","name":"NAME"}
{"action":"click","selector":"SEL"}
{"action":"fill","selector":"SEL","value":"TEXT"}
{"action":"text","selector":"SEL"}
{"action":"title"}
{"action":"done","summary":"SUMMARY"}
{"action":"fail","reason":"WHY"}

RULES:
1. Complete EVERY part of the task before using done
2. If task says "take screenshot", you MUST take a screenshot
3. If task says "click X", you MUST click X
4. Only use done after ALL requested actions are complete
5. Respond with JSON only, no markdown

Example: "go to google.com, screenshot it, tell me title"
→ {"action":"navigate","url":"https://google.com"}
→ {"action":"screenshot","name":"google"}
→ {"action":"title"}
→ {"action":"done","summary":"Title: Google. Screenshot saved."}'

HISTORY=""

call_llm() {
    local msg="$1"
    local messages="[{\"role\":\"system\",\"content\":$(echo "$SYSTEM_PROMPT" | jq -Rs .)}$HISTORY,{\"role\":\"user\",\"content\":$(echo "$msg" | jq -Rs .)}]"

    local resp=$(curl -s https://openrouter.ai/api/v1/chat/completions \
        -H "Authorization: Bearer $OPENROUTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":$messages,\"max_tokens\":500}")

    local content=$(echo "$resp" | jq -r '.choices[0].message.content // "Error"')
    HISTORY="$HISTORY,{\"role\":\"user\",\"content\":$(echo "$msg" | jq -Rs .)},{\"role\":\"assistant\",\"content\":$(echo "$content" | jq -Rs .)}"
    echo "$content"
}

# Create the Playwright test runner
run_action() {
    local json="$1"
    local action=$(echo "$json" | jq -r '.action')

    case "$action" in
        navigate)
            local url=$(echo "$json" | jq -r '.url')
            node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: $HEADLESS });
    const page = await browser.newPage();
    await page.goto('$url');
    const title = await page.title();
    console.log(JSON.stringify({ success: true, title, url: page.url() }));
    // Save state for next action
    const fs = require('fs');
    fs.writeFileSync('/tmp/browser-state.json', JSON.stringify({ url: page.url() }));
    await browser.close();
})();
" 2>&1
            ;;
        screenshot)
            local name=$(echo "$json" | jq -r '.name // "shot"')
            local path="$SCREENSHOT_DIR/${name}-$(date +%s).png"
            local state=$(cat /tmp/browser-state.json 2>/dev/null || echo '{"url":"about:blank"}')
            local url=$(echo "$state" | jq -r '.url')
            node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: $HEADLESS });
    const page = await browser.newPage();
    await page.goto('$url');
    await page.screenshot({ path: '$path', fullPage: true });
    console.log(JSON.stringify({ success: true, path: '$path' }));
    await browser.close();
})();
" 2>&1
            ;;
        click)
            local sel=$(echo "$json" | jq -r '.selector')
            local state=$(cat /tmp/browser-state.json 2>/dev/null || echo '{"url":"about:blank"}')
            local url=$(echo "$state" | jq -r '.url')
            node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: $HEADLESS });
    const page = await browser.newPage();
    await page.goto('$url');
    await page.click('$sel');
    const fs = require('fs');
    fs.writeFileSync('/tmp/browser-state.json', JSON.stringify({ url: page.url() }));
    console.log(JSON.stringify({ success: true, clicked: '$sel', url: page.url() }));
    await browser.close();
})();
" 2>&1
            ;;
        fill)
            local sel=$(echo "$json" | jq -r '.selector')
            local val=$(echo "$json" | jq -r '.value')
            local state=$(cat /tmp/browser-state.json 2>/dev/null || echo '{"url":"about:blank"}')
            local url=$(echo "$state" | jq -r '.url')
            node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: $HEADLESS });
    const page = await browser.newPage();
    await page.goto('$url');
    await page.fill('$sel', '$val');
    console.log(JSON.stringify({ success: true, filled: '$sel' }));
    await browser.close();
})();
" 2>&1
            ;;
        text)
            local sel=$(echo "$json" | jq -r '.selector // "body"')
            local state=$(cat /tmp/browser-state.json 2>/dev/null || echo '{"url":"about:blank"}')
            local url=$(echo "$state" | jq -r '.url')
            node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: $HEADLESS });
    const page = await browser.newPage();
    await page.goto('$url');
    const text = await page.innerText('$sel');
    console.log(JSON.stringify({ success: true, text: text.substring(0, 2000) }));
    await browser.close();
})();
" 2>&1
            ;;
        title)
            local state=$(cat /tmp/browser-state.json 2>/dev/null || echo '{"url":"about:blank"}')
            local url=$(echo "$state" | jq -r '.url')
            node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: $HEADLESS });
    const page = await browser.newPage();
    await page.goto('$url');
    const title = await page.title();
    console.log(JSON.stringify({ success: true, title }));
    await browser.close();
})();
" 2>&1
            ;;
        done|fail)
            echo "$json"
            ;;
        *)
            echo '{"success":false,"error":"Unknown action"}'
            ;;
    esac
}

extract_json() {
    echo "$1" | grep -oP '\{[^{}]*\}' | head -1
}

echo "🤖 Browser Agent" >&2
echo "📋 Task: $TASK" >&2
echo "" >&2

iter=0
# Parse task into explicit steps
msg="Task: $TASK

Break this into steps. Execute step 1 now."

while [ $iter -lt $MAX_ITERATIONS ]; do
    iter=$((iter + 1))
    echo "━━━ Step $iter ━━━" >&2

    echo "🧠 Thinking..." >&2
    resp=$(call_llm "$msg")
    echo "$resp" >> "$LOG_FILE"

    json=$(extract_json "$resp")
    [ -z "$json" ] && { msg="Respond with JSON: {\"action\":\"...\"}"; continue; }

    action=$(echo "$json" | jq -r '.action')
    echo "📌 $action" >&2

    if [ "$action" = "done" ]; then
        # Check if required actions were completed
        if [[ "$TASK" == *screenshot* ]] && ! grep -q '"action":"screenshot"' "$LOG_FILE"; then
            echo "⚠️  Screenshot required but not taken" >&2
            msg="You said done but the task requires a screenshot. Take the screenshot first."
            continue
        fi
        summary=$(echo "$json" | jq -r '.summary // "Complete"')
        echo "✅ $summary" >&2
        echo "$summary"
        exit 0
    fi

    if [ "$action" = "fail" ]; then
        reason=$(echo "$json" | jq -r '.reason // "Failed"')
        echo "❌ $reason" >&2
        exit 1
    fi

    echo "⚡ Running..." >&2
    result=$(run_action "$json" 2>&1 | tail -1)
    echo "📤 $(echo "$result" | head -c 100)..." >&2

    # Check if task mentions screenshot but we haven't done one
    PENDING=""
    if [[ "$TASK" == *screenshot* ]] && [[ "$action" != "screenshot" ]] && ! grep -q '"action":"screenshot"' "$LOG_FILE"; then
        PENDING="NOTE: Task requires screenshot - you haven't taken one yet. "
    fi

    msg="${PENDING}Result: $result

Continue with next required action, or done if ALL task steps complete."
    echo "" >&2
done

echo "⚠️ Max iterations" >&2
exit 1
