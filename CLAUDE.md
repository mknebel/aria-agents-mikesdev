# Global Rules - FOLLOW STRICTLY

## CRITICAL: Use Aria Agent System
**ALWAYS delegate tasks to subagents to reduce token usage on Claude.**

| Task Type | Subagent | Why |
|-----------|----------|-----|
| Coding/implementation | `aria-coder` | Full-stack dev |
| Code exploration | `Explore` | Fast file/code search |
| Testing/QA | `aria-qa` | Validation, bugs |
| Git/admin tasks | `aria-admin` | Changelogs, commits |
| Documentation | `aria-docs` | Docs, worklogs |
| Architecture questions | `aria-architect` | System design |
| Security review | `code-review` | Before commits |
| Complex routing | `aria` | Main orchestrator |

**How**: Use Task tool with `subagent_type` parameter. Spawn agents in parallel when possible.

**Claude direct use ONLY for**: Quick answers, clarifications, planning decisions, user interaction.

## CRITICAL: Avoid Redundant Tool Calls
1. **NEVER make duplicate searches** - if you already searched for something, don't search again
2. **Combine search patterns**: Use `(pattern1|pattern2|pattern3)` instead of 3 separate calls
3. **Max 3 search calls** per task before synthesizing results
4. **Read files once** - don't re-read the same file in one session

## Tool Efficiency Rules
| Tool | Rule |
|------|------|
| Grep/Search | Combine patterns with `\|`, max 3 calls, then analyze |
| Read | Read once per file, use offset/limit for large files |
| Edit | Use MultiEdit for same file, parallel Edit for different files |
| Bash | Chain with `&&`, use absolute paths |

## Auto (via hooks)
Grep context, read limits, caching, indexing, token tracking

## Commands
`/menu` `/cost-report` `/index-project` `/summarize`
