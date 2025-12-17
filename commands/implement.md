---
description: Implement with quality chain (92%+ accuracy)
argument-hint: <task description>
---

# Implement Command - Quality Chain

Execute the full quality chain for 92%+ code accuracy.

## Arguments
```
$ARGUMENTS = The task to implement
```

## Quality Chain Steps

### Step 1: Context (FREE)
Ensure project is indexed and session has context:
- Check if index exists: `~/.claude/indexes/`
- If not: Run `/index-project` first
- Session context from `aria session`

### Step 2: Generate Code (Pro flat rate)
Use codex-max with maximum reasoning:
```bash
aria route max "$ARGUMENTS"
```
Save the generated code to a temporary location or display for review.

### Step 3: Claude Review (YOUR JOB - 2k tokens)
Review the generated code for:
```
□ Consistency with existing codebase patterns
□ Complete implementation (nothing missed)
□ Theme/style adherence (Bootstrap, Porto Admin, etc.)
□ Security (no injection, XSS, SQL injection)
□ Error handling and edge cases
□ Database patterns (soft deletes, multi-tenant)
□ No breaking changes
```

If issues found:
- List specific problems
- Re-generate with feedback: `aria route max "fix: [issues]"`
- Repeat until approved

### Step 4: Apply Changes
Once Claude approves:
- Use Edit/Write tools to apply the code
- Log to agent context: `aria context add aria-coder "implemented [feature]"`

### Step 5: Quality Gate (FREE)
Run quality checks:
```bash
/quality
```
Or manually:
```bash
~/.claude/scripts/quality-gate.sh
```

### Step 6: Iterate if Needed
If quality gate fails:
- Review errors
- Re-generate with specific fixes
- Repeat steps 3-5

## Example Flow

User: `/implement user authentication with login/logout`

1. **Context**: Check index, load session
2. **Generate**: `aria route max "implement user authentication with login/logout for CakePHP 4"`
3. **Review**: Claude checks patterns, security, completeness
4. **Apply**: Edit files with approved code
5. **Quality**: Run `/quality`
6. **Done**: Log to context

## Expected Outcome

| Metric | Value |
|--------|-------|
| Code accuracy | 92%+ |
| Claude tokens | ~2k (review only) |
| External cost | Pro sub (flat) |

## Notes

- Claude does NOT generate code - only reviews
- Codex does the heavy lifting (77.9% base accuracy)
- Claude review adds 10-15% accuracy
- Quality gate catches remaining 3-5%
- Total: 92%+ accuracy at 87% token savings
