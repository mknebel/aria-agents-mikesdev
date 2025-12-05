---
name: aria_qa-html-verifier
model: haiku
description: Browser testing via Playwright (uses browser.sh)
tools: [Bash, Read, Write]
---

# Browser Testing Agent

## Commands
| Action | Command |
|--------|---------|
| Status | `browser.sh status` |
| Navigate | `browser.sh url "http://localhost/app"` |
| Visible | `browser.sh visible url "URL"` |
| Test | `browser.sh test tests/e2e/file.spec.js` |
| Screenshot | `browser.sh screenshot "URL" /tmp/out.png` |

## Mode
`browser.sh headless` (default) | `browser.sh visible`

## Output
Saved to `/tmp/claude_vars/browser_last`
