---
description: Self-review checklist before committing
allowed-tools: Bash, Grep, Read
---

Run a quality review checklist on staged/modified files.

```bash
echo "=== Code Review Checklist ==="
echo ""

# Get changed files
CHANGED=$(git diff --name-only HEAD 2>/dev/null || git diff --name-only)
STAGED=$(git diff --cached --name-only 2>/dev/null)

if [[ -z "$CHANGED" && -z "$STAGED" ]]; then
    echo "No changes to review."
    exit 0
fi

echo "Files to review:"
echo "$CHANGED" "$STAGED" | sort -u | head -20
echo ""
```

Now analyze the changes and check for:

## Security
- [ ] No hardcoded secrets, API keys, or passwords
- [ ] No SQL injection vulnerabilities (use parameterized queries)
- [ ] No XSS vulnerabilities (escape output)
- [ ] No sensitive data in logs

## Code Quality
- [ ] No TODO/FIXME left unaddressed
- [ ] No commented-out code blocks
- [ ] No debug statements (console.log, var_dump, print_r)
- [ ] Functions are reasonably sized (<50 lines)
- [ ] Clear variable/function names

## Logic
- [ ] Edge cases handled (null, empty, zero)
- [ ] Error handling in place
- [ ] No infinite loops or recursion risks
- [ ] Database transactions where needed

## Testing
- [ ] New code has tests (or explain why not)
- [ ] Existing tests still pass
- [ ] Edge cases tested

Run quick automated checks:
```bash
echo "=== Automated Checks ==="

# Check for debug statements
echo "Debug statements:"
git diff HEAD --name-only | xargs grep -l -E '(console\.log|var_dump|print_r|dd\(|dump\()' 2>/dev/null || echo "  None found"

# Check for TODOs in changed files
echo ""
echo "TODOs in changed files:"
git diff HEAD --name-only | xargs grep -n "TODO\|FIXME" 2>/dev/null || echo "  None found"

# Check for hardcoded secrets patterns
echo ""
echo "Potential secrets (review these):"
git diff HEAD | grep -E "(password|secret|api_key|apikey|token).*[=:].*['\"][^'\"]{8,}" -i 2>/dev/null || echo "  None detected"
```

Provide a summary of any issues found and recommendations.
