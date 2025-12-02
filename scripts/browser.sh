#!/bin/bash
# Browser automation wrapper with headless toggle
# Usage:
#   browser.sh status                    - Show current mode
#   browser.sh headless                  - Set mode to headless
#   browser.sh visible                   - Set mode to visible
#   browser.sh [headless|visible] <action> [args]  - Override for this call
#   browser.sh <action> [args]           - Use stored mode
#
# Default: headless (if mode file doesn't exist)

MODE_FILE="$HOME/.claude/browser-mode"
DEFAULT_MODE="headless"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

get_mode() {
    if [ -f "$MODE_FILE" ]; then
        cat "$MODE_FILE"
    else
        echo "$DEFAULT_MODE"
    fi
}

set_mode() {
    echo "$1" > "$MODE_FILE"
}

MODE_OVERRIDE=""
MODE=$(get_mode)

# Handle status/set commands
case "$1" in
    status)
        echo "browser mode: $MODE"
        [ ! -f "$MODE_FILE" ] && echo "(using default, no mode file)"
        exit 0
        ;;
    headless|visible)
        if [ $# -eq 1 ]; then
            # Just setting mode, no action
            set_mode "$1"
            echo "browser mode set to: $1"
            exit 0
        else
            # Per-call override
            MODE_OVERRIDE="$1"
            shift
        fi
        ;;
esac

ACTION="$1"
shift

# Final mode for this call
EFFECTIVE_MODE="${MODE_OVERRIDE:-$MODE}"
HEADLESS_FLAG=$([[ "$EFFECTIVE_MODE" == "headless" ]] && echo "true" || echo "false")

# Dispatch actions
case "$ACTION" in
    navigate|nav)
        URL="$1"
        echo "🌐 Navigating to $URL (mode: $EFFECTIVE_MODE)..." >&2

        # Run Playwright test
        cd /tmp
        npx playwright test --project=chromium \
            $([[ "$EFFECTIVE_MODE" == "visible" ]] && echo "--headed") \
            --reporter=line \
            -x <<EOF 2>&1 | tee "$VAR_DIR/browser_last"
import { test } from '@playwright/test';
test('navigate', async ({ page }) => {
    await page.goto('$URL');
    const html = await page.content();
    console.log('PAGE_CONTENT_START');
    console.log(html.substring(0, 5000));
    console.log('PAGE_CONTENT_END');
});
EOF
        echo "📁 Output saved to \$browser_last" >&2
        ;;

    click)
        SELECTOR="$1"
        echo "🖱️ Click: $SELECTOR (mode: $EFFECTIVE_MODE)" >&2
        echo "click:$SELECTOR" >> "$VAR_DIR/browser_actions"
        ;;

    fill|type)
        SELECTOR="$1"
        VALUE="$2"
        echo "⌨️ Fill: $SELECTOR = '$VALUE' (mode: $EFFECTIVE_MODE)" >&2
        echo "fill:$SELECTOR:$VALUE" >> "$VAR_DIR/browser_actions"
        ;;

    screenshot|ss)
        OUTPUT="${1:-/tmp/screenshot-$(date +%s).png}"
        echo "📸 Screenshot: $OUTPUT (mode: $EFFECTIVE_MODE)" >&2
        echo "screenshot:$OUTPUT" >> "$VAR_DIR/browser_actions"
        ;;

    run)
        # Execute queued actions
        ACTIONS_FILE="$VAR_DIR/browser_actions"
        if [ ! -f "$ACTIONS_FILE" ]; then
            echo "No actions queued. Use click, fill, screenshot first." >&2
            exit 1
        fi
        echo "▶️ Running $(wc -l < "$ACTIONS_FILE") queued actions..." >&2
        cat "$ACTIONS_FILE"
        rm "$ACTIONS_FILE"
        ;;

    help|"")
        cat << 'HELP'
Browser Automation Wrapper

Usage:
  browser.sh status                 Show current mode
  browser.sh headless               Set mode (persistent)
  browser.sh visible                Set mode (persistent)
  browser.sh <action> [args]        Run with stored mode
  browser.sh visible <action>       Override mode for this call

Actions:
  navigate <url>        Open URL and get HTML
  click <selector>      Queue click action
  fill <sel> <value>    Queue form fill
  screenshot [path]     Queue screenshot
  run                   Execute queued actions

Mode file: ~/.claude/browser-mode
Default: headless

Examples:
  browser.sh navigate "http://localhost/app"
  browser.sh visible navigate "http://localhost/app"
  browser.sh click "#login-btn"
  browser.sh fill "#email" "test@example.com"
  browser.sh run
HELP
        ;;

    *)
        echo "Unknown action: $ACTION" >&2
        echo "Run 'browser.sh help' for usage" >&2
        exit 1
        ;;
esac
