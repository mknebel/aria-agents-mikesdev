---
description: List available aria agents and their purposes
---

# Aria Agents

```bash
ls ~/.claude/agents/*.md
```

## Agent Routing

| Agent | Model | Use For |
|-------|-------|---------|
| aria | sonnet | Main orchestrator |
| aria-thinking | opus | Complex/failed tasks |
| aria-architect | sonnet | System design |
| aria-coder | haiku | Full-stack implementation |
| aria-qa | haiku | Testing, validation |
| aria-docs | haiku | Documentation |
| aria-admin | haiku | Git, task management |
| aria-devops | haiku | CI/CD, deployment |
| aria-ui-ux | haiku | UI/UX design |
| code-review | sonnet | Security, code quality |

## Invoke Agent

Use Task tool with `subagent_type: <agent-name>`
