# Example Usage of ARIA/APEX Sub-Agents

## Quick Examples

### 1. Building a Complete Feature

Instead of:
```
"Build a blog system with posts, comments, and categories"
```

Use:
```
"Use the parallel-work-manager to build a blog system with posts, comments, and categories"
```

This will automatically delegate to:
- aria-architect: Design database schema
- aria-coder-backend: Create models and APIs
- aria-coder-frontend: Build UI components
- aria-qa: Write tests
- aria-docs: Create documentation

### 2. Fixing Multiple Bugs

Instead of:
```
"Fix all the bugs in the issue tracker"
```

Use:
```
"Use the parallel-work-manager to fix bugs #123, #124, #125, and #126"
```

This assigns each bug to different coders working simultaneously.

### 3. API Development

Instead of:
```
"Create a RESTful API for user management"
```

Use:
```
"Use the aria-coder-api to create a RESTful API for user management with full documentation"
```

### 4. Complex System Implementation

```
"Use the aria-delegator to implement a complete e-commerce checkout system with cart, payment processing, order management, and email notifications"
```

The delegator will:
1. Break down the requirements
2. Create subtasks for each component
3. Delegate to appropriate specialists
4. Track progress in database
5. Ensure quality standards

### 5. Performance Optimization

```
"Use the aria-coder-3 to optimize the database queries and improve page load times"
```

CODER_3 specializes in debugging and optimization.

### 6. Emergency Fixes

```
"Use aria-coder-4 to apply security patches and update all dependencies"
```

CODER_4 handles maintenance and urgent updates.

## Real-World Scenarios

### Scenario 1: New Feature Development

**Task**: Add multi-language support to existing application

**Sequential approach** (slow):
1. Research i18n libraries (30 min)
2. Design database schema (30 min)
3. Implement backend (2 hours)
4. Update all views (3 hours)
5. Test translations (1 hour)
Total: ~7 hours

**Parallel sub-agent approach**:
```
"Use the parallel-work-manager to implement multi-language support"
```

Executes simultaneously:
- aria-architect: Design i18n architecture
- aria-coder-backend: Implement translation system
- aria-coder-frontend: Update UI components
- aria-qa: Create language tests
Total: ~3 hours (longest task)

### Scenario 2: Technical Debt Cleanup

```
"Use the parallel-work-manager to refactor all deprecated code and update to latest framework version"
```

Delegates to:
- aria-coder-1: Update core dependencies
- aria-coder-2: Refactor deprecated methods
- aria-coder-3: Optimize performance
- aria-coder-4: Update configurations

### Scenario 3: Complete CRUD System

```
"Use the aria-delegator to create a complete inventory management system with products, categories, suppliers, and reporting"
```

## Tips for Effective Use

1. **Be Specific**: Give clear requirements to the orchestrator
2. **Include Context**: Mention framework, database, existing patterns
3. **Set Priorities**: Indicate what's most important
4. **Check Progress**: Monitor database for task status
5. **Trust the Agents**: Let them work autonomously

## Monitoring Progress

```bash
# Check active tasks
mysql -h 127.0.0.1 -u us1647a -pmike agent_central -e "
SELECT t.task_id, t.title, t.status, aa.agent_code
FROM tasks t
LEFT JOIN agent_tasks aa ON t.task_id = aa.task_id
WHERE t.status = 'in_progress';"

# View agent performance
mysql -h 127.0.0.1 -u us1647a -pmike agent_central -e "
SELECT agent_code, total_tasks, completed_tasks, success_rate
FROM agent_performance
ORDER BY success_rate DESC;"
```