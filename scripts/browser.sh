#!/bin/bash
# Browser automation wrapper with headless toggle
# Usage: browser.sh [headless|visible] <action> <args...>
#        browser.sh navigate "http://example.com"
#        browser.sh visible click "#submit"
#
# Reads default mode from ~/.claude/browser-mode

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

# Check for mode override as first arg
MODE=$(cat ~/.claude/browser-mode 2>/dev/null || echo "headless")
if [ "$1" = "headless" ] || [ "$1" = "visible" ]; then
    MODE="$1"
    shift
fi

ACTION="${1:-help}"
shift

HEADLESS_FLAG="true"
[ "$MODE" = "visible" ] && HEADLESS_FLAG="false"

case "$ACTION" in
    navigate|nav)
        URL="$1"
        echo "🌐 Navigating to $URL (mode: $MODE)..." >&2
        npx playwright test --browser=chromium --headed=$([[ "$MODE" = "visible" ]] && echo "true" || echo "") \
            -c - <<EOF 2>&1 | tee "$VAR_DIR/browser_last"
const { test, expect } = require('@playwright/test');
test('navigate', async ({ page }) => {
    await page.goto('$URL');
    console.log(await page.content());
});
EOF
        ;;

    click)
        SELECTOR="$1"
        echo "🖱️ Clicking $SELECTOR (mode: $MODE)..." >&2
        # Store action for next tool
        echo "click:$SELECTOR" > "$VAR_DIR/browser_action"
        ;;

    screenshot|ss)
        OUTPUT="${1:-/tmp/screenshot.png}"
        echo "📸 Screenshot to $OUTPUT (mode: $MODE)..." >&2
        echo "screenshot:$OUTPUT" > "$VAR_DIR/browser_action"
        ;;

    fill)
        SELECTOR="$1"
        VALUE="$2"
        echo "⌨️ Filling $SELECTOR (mode: $MODE)..." >&2
        echo "fill:$SELECTOR:$VALUE" > "$VAR_DIR/browser_action"
        ;;

    status)
        echo "Browser mode: $MODE"
        echo "Headless: $HEADLESS_FLAG"
        ;;

    help|*)
        cat << 'EOF'
Browser Automation Wrapper

Usage: browser.sh [mode] <action> [args]

Modes:
  headless  - Run without visible browser (default)
  visible   - Run with visible browser window

Actions:
  navigate <url>       - Open URL
  click <selector>     - Click element
  fill <selector> <v>  - Fill input field
  screenshot [path]    - Take screenshot
  status               - Show current mode

Examples:
  browser.sh navigate "http://localhost/app"
  browser.sh visible click "#login-btn"
  browser.sh screenshot /tmp/test.png

Mode is read from ~/.claude/browser-mode
Override with: echo "visible" > ~/.claude/browser-mode
EOF
        ;;
esac
