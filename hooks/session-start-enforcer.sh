#!/bin/bash
# Session Start Enforcer - Reinforces mandatory workflow
# Runs on SessionStart to remind Claude of workflow requirements

cat << 'WORKFLOW_REMINDER'
{
  "status": "success",
  "reminder": "🎯 MANDATORY Workflow Active (see ~/.claude/CLAUDE.md)",
  "rules": [
    "✅ Parallel-First: Spawn multiple subagents for independent tasks",
    "✅ ARIA-First: Start with 'aria route context' (Gemini 1M, FREE)",
    "✅ Justfile-First: Use 'just' commands (cx, st, ci, co) - 90% token savings",
    "✅ Maintainability-First: Clean code, clear patterns, long-term thinking"
  ],
  "quick_reference": {
    "context": "aria route context 'gather X'",
    "search": "just cx 'query'",
    "commit": "just ci 'message'",
    "commands": "just --list"
  }
}
WORKFLOW_REMINDER

exit 0
