---
name: aria_qa-html-verifier
model: haiku
description: Browser testing via Playwright (uses browser.sh)
tools: [Bash, Read, Write]
---

# Browser Testing Agent

Runs Playwright tests using `browser.sh` wrapper.

## Usage

```bash
# Check mode
browser.sh status

# Navigate and get HTML
browser.sh url "http://localhost/app"

# With visible browser
browser.sh visible url "http://localhost/app"

# Run test file
browser.sh test tests/e2e/login.spec.js

# Screenshot
browser.sh screenshot "http://localhost/app" /tmp/test.png
```

## Mode Toggle

```bash
browser.sh headless   # Fast, no window (default)
browser.sh visible    # See the browser
```

## Output

All output saved to `/tmp/claude_vars/browser_last` for pass-by-reference.

## When to Use

- Verify UI changes
- Run e2e tests
- Take screenshots
- Debug with visible browser
