# Common Agent Rules

## External Tools (FREE)
| Task | Command |
|------|---------|
| Search | `ctx "query"` |
| Code gen | `codex-save.sh "prompt"` |
| Large context | `gemini "prompt" @files` |
| Quick gen | `ai.sh fast "prompt"` |

## Variables
Files in `/tmp/claude_vars/`: `codex_last`, `gemini_context`, `ctx_last`, `grep_last`

Read: `cat /tmp/claude_vars/NAME` | Reference: `@var:NAME` | Never inline.

## Handoff
Small: instruction + file refs. Extensive: file:line list + var refs.

## Cache Check
`find /tmp/claude_vars/FILE -mmin -10` → Skip if fresh.

## Rules
1. Check cache BEFORE external calls
2. External tools first, Claude reviews
3. Never generate >50 lines (use codex)
4. Read from /tmp/claude_vars/, don't repeat
