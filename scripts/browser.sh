#!/bin/bash
# Simple browser automation via Playwright
# Usage:
#   browser.sh status                 - Show current mode
#   browser.sh headless               - Set mode to headless (persistent)
#   browser.sh visible                - Set mode to visible (persistent)
#   browser.sh [visible] url <url>    - Navigate and get HTML
#   browser.sh [visible] test <file>  - Run Playwright test file
#
# Default: headless (if mode file doesn't exist)
# Output saved to /tmp/claude_vars/browser_last

MODE_FILE="$HOME/.claude/browser-mode"
DEFAULT_MODE="headless"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

get_mode() {
    [ -f "$MODE_FILE" ] && cat "$MODE_FILE" || echo "$DEFAULT_MODE"
}

set_mode() {
    echo "$1" > "$MODE_FILE"
    echo "browser mode: $1"
}

# Handle mode override as first arg
MODE=$(get_mode)
if [ "$1" = "visible" ] || [ "$1" = "headless" ]; then
    if [ $# -eq 1 ]; then
        set_mode "$1"
        exit 0
    fi
    MODE="$1"
    shift
fi

ACTION="$1"
shift

case "$ACTION" in
    status)
        echo "browser mode: $MODE"
        ;;

    url|navigate|nav)
        URL="$1"
        echo "🌐 $URL (mode: $MODE)" >&2

        HEADED_FLAG=""
        [ "$MODE" = "visible" ] && HEADED_FLAG="--headed"

        npx playwright test --browser=chromium $HEADED_FLAG --reporter=list -x - <<'TESTEOF' 2>&1 | tee "$VAR_DIR/browser_last"
import { test } from '@playwright/test';
test('navigate', async ({ page }) => {
    await page.goto(process.env.TEST_URL);
    console.log(await page.content());
});
TESTEOF
        echo "📁 Saved to \$browser_last" >&2
        ;;

    test|run)
        FILE="$1"
        [ ! -f "$FILE" ] && echo "File not found: $FILE" >&2 && exit 1

        echo "▶️ Running $FILE (mode: $MODE)" >&2

        HEADED_FLAG=""
        [ "$MODE" = "visible" ] && HEADED_FLAG="--headed"

        npx playwright test "$FILE" --browser=chromium $HEADED_FLAG --reporter=list 2>&1 | tee "$VAR_DIR/browser_last"
        echo "📁 Saved to \$browser_last" >&2
        ;;

    screenshot|ss)
        URL="$1"
        OUTPUT="${2:-/tmp/screenshot-$(date +%s).png}"
        echo "📸 $URL → $OUTPUT (mode: $MODE)" >&2

        HEADED_FLAG=""
        [ "$MODE" = "visible" ] && HEADED_FLAG="--headed"

        TEST_URL="$URL" SCREENSHOT_PATH="$OUTPUT" npx playwright test --browser=chromium $HEADED_FLAG -x - <<'TESTEOF' 2>&1
import { test } from '@playwright/test';
test('screenshot', async ({ page }) => {
    await page.goto(process.env.TEST_URL);
    await page.screenshot({ path: process.env.SCREENSHOT_PATH, fullPage: true });
    console.log('Screenshot saved to: ' + process.env.SCREENSHOT_PATH);
});
TESTEOF
        ;;

    *)
        cat << 'HELP'
Browser Automation (Playwright)

Mode:
  browser.sh status         Show current mode
  browser.sh headless       Set mode (persistent)
  browser.sh visible        Set mode (persistent)

Actions:
  browser.sh url <url>              Navigate, get HTML
  browser.sh visible url <url>      Same, with visible browser
  browser.sh test <file.spec.js>    Run Playwright test
  browser.sh screenshot <url> [path] Take screenshot

Output: /tmp/claude_vars/browser_last
Mode file: ~/.claude/browser-mode (default: headless)
HELP
        ;;
esac
