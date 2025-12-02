---
description: Toggle browser mode (headless/visible) or check status
argument-hint: [headless|visible|status]
---

# Browser Mode Toggle

Based on the argument provided:

- **"headless"**: Run `echo "headless" > ~/.claude/browser-mode` and confirm headless mode is active
- **"visible"**: Run `echo "visible" > ~/.claude/browser-mode` and confirm visible mode is active
- **"status"** or no argument: Run `cat ~/.claude/browser-mode` and show current mode

Also show a reminder of how to use browser automation:
- MCP tools: Use aria_qa-html-verifier agent for Playwright MCP tools
- Script: `browser.sh navigate "http://..."` or `browser.sh visible click "#btn"`
