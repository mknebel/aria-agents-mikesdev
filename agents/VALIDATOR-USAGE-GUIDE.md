# ARIA Validator Usage Guide

Complete guide for using the aria-validator agent to ensure task completion quality.

## When to Use aria-validator

**ALWAYS validate before marking tasks complete:**
- ✅ After implementing new features
- ✅ After bug fixes
- ✅ After refactoring
- ✅ After API changes
- ✅ Before final approval
- ✅ When user requests validation

**Examples:**
- "Verify the user authentication feature is complete"
- "Validate the API endpoint implementation"
- "Check if all requirements for the dashboard were met"

## How to Invoke

### Method 1: Direct Request (Recommended)

User can directly request validation:
```
"Use aria-validator to verify the theme implementation task is complete"
```

### Method 2: Through aria-delegator

Delegator automatically invokes validator as final step:
```
aria-delegator receives task → delegates to coders → delegates to validator → reports results
```

### Method 3: As Part of Workflow

Include in your workflow prompts:
```
"After implementing X, use aria-validator to ensure all requirements met"
```

## Example Workflows

### Simple Feature Implementation

```
User: "Add dark mode toggle to settings page"

1. aria-delegator analyzes task
2. Delegates to aria-coder-frontend for implementation
3. Delegates to aria-qa for testing
4. Delegates to aria-validator for validation
5. Validator reports: ✅ APPROVED or ❌ NEEDS WORK
```

### Complex Multi-Component Task

```
User: "Build user registration system with email verification"

1. aria-delegator breaks into subtasks:
   - Database schema (aria-architect)
   - Backend API (aria-coder-backend)
   - Frontend forms (aria-coder-frontend)
   - Email service (aria-coder-api)
   - Tests (aria-qa)
   - Docs (aria-docs)

2. After all subtasks complete:
   - aria-validator validates entire system
   - Checks integration between components
   - Verifies all original requirements
   - Reports completion status
```

## Validation Report Example

```markdown
## Task Validation Report: Add Dark Mode Toggle

### ✅ Requirements Met (4/4)
1. Toggle button in settings - ✅ templates/layout/default-admin-unified.php:245
2. Dark mode CSS - ✅ webroot/css/dark-mode.css
3. JavaScript toggle - ✅ webroot/js/theme-toggle.js
4. Persistence (localStorage) - ✅ webroot/js/theme-toggle.js:15

### 🧪 Test Results
- Manual Testing: ✅ Toggle works
- Browser Compatibility: ✅ Chrome, Firefox, Safari
- Code Quality: ✅ No linting errors

### 🔍 Code Review Findings
**Strengths:**
- Clean implementation
- Good user experience
- No conflicts with existing themes

**Issues Found:**
- None

### 📋 Completion Status
**Overall: APPROVED ✅**

**Next Steps:** Ready to merge/deploy
```

## Best Practices

### For Users

**DO:**
- ✅ Request validation before considering task complete
- ✅ Provide original requirements/tickets for reference
- ✅ Allow validator access to test results
- ✅ Act on validator feedback

**DON'T:**
- ❌ Skip validation for "simple" tasks
- ❌ Ignore validator warnings
- ❌ Mark tasks complete without validation
- ❌ Argue with validation results (fix issues instead)

### For Developers

**Integration:**
```bash
# In your workflow after implementation
Task(
    description="Validate user auth implementation",
    prompt="Original task: [paste requirements]

    Files changed:
    - src/Controller/UsersController.php
    - templates/Users/login.php
    - tests/TestCase/Controller/UsersControllerTest.php

    Verify all requirements met and tests pass.",
    subagent_type="aria-validator"
)
```

## Common Validation Scenarios

### Feature Implementation ✅
**Checks:**
- All requirements in original request
- UI matches specifications
- Edge cases handled
- Tests written and passing
- No security issues
- Performance acceptable

### Bug Fix 🐛
**Checks:**
- Root cause fixed (not just symptoms)
- Regression test added
- Bug doesn't reappear
- No new bugs introduced
- Related bugs checked

### Refactoring 🔄
**Checks:**
- Functionality unchanged
- All tests still pass
- Performance same or better
- Code cleaner/more maintainable
- No breaking changes

### API Changes 🔌
**Checks:**
- Endpoints work as documented
- Request/response formats correct
- Authentication works
- Error responses appropriate
- Backward compatibility (if needed)

## Failure Handling

### If Validation Fails ❌

**Validator provides:**
- Specific missing requirements
- Failed tests
- Issues found
- Action items to fix

**Response:**
1. Review validator report
2. Fix identified issues
3. Re-run tests
4. Request re-validation
5. Repeat until approved

**Example:**
```markdown
## Validation Failed ❌

Missing Requirements:
- [ ] Email verification link not implemented
- [ ] Password reset not functional

Failed Tests:
- testUserRegistration: Expected email sent (0 sent)

Action Items:
1. Implement email service integration
2. Add email verification controller
3. Write tests for email sending
4. Re-test entire flow
```

## Integration with Database

Validator can update task status:
```sql
-- After validation passes
UPDATE tasks
SET status = 'validated',
    validation_passed = TRUE,
    validated_at = NOW()
WHERE task_id = {id};

-- If validation fails
UPDATE tasks
SET status = 'needs_rework',
    validation_passed = FALSE,
    validation_notes = 'Missing email verification'
WHERE task_id = {id};
```

## Tips for Success

1. **Be Specific:** Provide clear original requirements
2. **Run Tests First:** Ensure tests pass before validation
3. **Include Context:** Reference related files/tickets
4. **Act on Feedback:** Don't ignore validator warnings
5. **Iterate:** Re-validate after fixes
6. **Document:** Keep validation reports for records

## Agent Location

**File:** `/mnt/d/MikesDev/.claude/agents/aria-validator.md`

**Line Count:** ~165 lines (compressed, efficient)

**Invocation:** Use Task tool with `subagent_type="aria-validator"`
