# Claude Code Sub-Agents for ARIA/APEX System

This directory contains properly formatted Claude Code sub-agents that enable parallel task execution for the ARIA/APEX development system.

## 🚀 Quick Start

### Using Sub-Agents Directly

```bash
# Claude Code will automatically detect and use these agents
"Use the aria-delegator to coordinate building a user authentication system"
"Use the aria-coder-backend to implement the API endpoints"
"Use the parallel-work-manager to build this feature quickly"
```

### Parallel Execution Pattern

```bash
# Instead of sequential work:
"Build login system"  # One agent does everything

# Use parallel delegation:
"Use the parallel-work-manager to build login system"
# This will delegate to multiple agents simultaneously:
# - aria-architect: Design schema
# - aria-coder-backend: Build API
# - aria-coder-frontend: Create UI
# - aria-qa: Write tests
# - aria-docs: Documentation
```

## 📁 Available Sub-Agents

### Orchestration Agents
- **aria-delegator** - Master orchestrator for complex multi-agent workflows
- **parallel-work-manager** - Breaks tasks into parallel sub-tasks

### Development Agents
- **aria-coder-backend** - PHP/API specialist (CakePHP, Laravel)
- **aria-coder-frontend** - JavaScript/UI specialist (React, jQuery)
- **aria-coder-api** - RESTful API and integration specialist
- **aria-coder-1** through **aria-coder-4** - General purpose parallel coders

### Specialized Agents
- **aria-architect** - System design and database schemas
- **aria-qa** - Testing and quality assurance
- **aria-ui-ux** - User interface and experience
- **aria-devops** - Deployment and infrastructure
- **aria-docs** - Documentation specialist

## 🎯 When to Use Which Agent

### For Complex Features
```bash
"Use the aria-delegator to implement shopping cart with payment integration"
# Delegator will coordinate multiple agents for different parts
```

### For Parallel Bug Fixes
```bash
"Use the parallel-work-manager to fix all critical bugs"
# Will assign bugs to different coders working simultaneously
```

### For Specific Tasks
```bash
"Use the aria-architect to design the database schema"
"Use the aria-qa to write comprehensive tests"
"Use the aria-docs to create API documentation"
```

## ⚡ Parallel Execution Benefits

### Traditional Approach (Sequential)
1. Analyze requirements (30 min)
2. Design database (45 min)
3. Build backend (2 hours)
4. Create frontend (2 hours)
5. Write tests (1 hour)
6. Document (30 min)
**Total: 6.5 hours**

### Parallel Sub-Agent Approach
All tasks run simultaneously:
- aria-architect: Design (45 min)
- aria-coder-backend: API (2 hours)
- aria-coder-frontend: UI (2 hours)
- aria-qa: Tests (1 hour)
- aria-docs: Documentation (30 min)
**Total: 2 hours** (longest task)

## 🔧 Configuration

### Database Integration
All agents update progress in MariaDB:
```sql
-- agent_central database
-- Tables: tasks, agent_tasks, agent_performance
```

### Project Context
Agents read from:
- `/mnt/d/MikesDev/CLAUDE.md` - Global context
- `.claude/agents/` - Agent definitions
- Project-specific CLAUDE.md files

## 📝 Creating Custom Sub-Agents

### Format Template
```markdown
---
name: your-agent-name
description: When this agent should be used
tools: Read, Write, Edit, Bash, Grep
---

You are [AGENT NAME], specialized in [DOMAIN].

## Core Responsibilities
1. [Responsibility 1]
2. [Responsibility 2]

## Guidelines
- [Guideline 1]
- [Guideline 2]
```

### Best Practices
1. **Single Responsibility** - Each agent should have one clear purpose
2. **Clear Triggers** - Description should make it obvious when to use
3. **Tool Restrictions** - Only include necessary tools
4. **Detailed Prompts** - Provide comprehensive context

## 🚨 Important Notes

### Reality Check
- Task() calls are **synchronous** (they block)
- But agents work **autonomously** (independently)
- Value is in **specialization** not true parallelism
- External orchestrator needed for true async

### When NOT to Use Sub-Agents
- Quick simple tasks (overhead not worth it)
- Interactive debugging (need real-time feedback)
- Tasks requiring coordination between steps

### When TO Use Sub-Agents
- Complex features with independent parts
- Multiple similar tasks (e.g., fixing many bugs)
- Tasks requiring different expertise
- When you can parallelize the thinking

## 🔄 Workflow Example

```javascript
// Main Claude Code session
"Use the parallel-work-manager to build user dashboard with analytics"

// Parallel Work Manager delegates:
Task("Design dashboard layout", "aria-ui-ux")
Task("Build backend analytics", "aria-coder-backend")  
Task("Create frontend charts", "aria-coder-frontend")
Task("Setup monitoring", "aria-devops")
Task("Write user guide", "aria-docs")

// All agents work autonomously
// Results aggregate when complete
```

## 📊 Performance Tracking

Agents automatically update metrics:
```sql
-- View agent performance
SELECT agent_code, 
       total_tasks, 
       completed_tasks,
       success_rate
FROM agent_performance
ORDER BY success_rate DESC;

-- View active tasks
SELECT * FROM agent_tasks
WHERE status = 'in_progress';
```

## 🆘 Troubleshooting

### Agent Not Found
- Ensure agent file is in `.claude/agents/`
- Check file has correct frontmatter format
- Verify name matches exactly

### Task Not Delegating
- Use explicit invocation: "Use the [agent-name] to..."
- Check agent description matches task
- Verify tools are appropriate

### Database Not Updating
- Check MariaDB connection
- Verify agent_central database exists
- Ensure tables are created

## 🎉 Getting Started

1. **Simple Task**: `"Use the aria-coder-backend to create user model"`
2. **Parallel Work**: `"Use the parallel-work-manager to build blog feature"`
3. **Complex Project**: `"Use the aria-delegator to create e-commerce platform"`

The agents are ready to accelerate your development workflow!