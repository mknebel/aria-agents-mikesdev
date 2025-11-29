# Search Efficiency Benchmark

## Pre-Optimization Baseline (Current Session)

### Tool Calls for Payment Analysis
```
● Grep(pattern: "function adnpayment|public function adnpayment", path: "register")
● Grep(pattern: "function chargeCustomerProfile", path: "register")
● Grep(pattern: "function chargeCustomerProfile", path: "LYK-Cake4-Admin")
● Read(register/src/Controller/OrderDetsController.php) - 200 lines
● Read(register/src/Controller/Component/AuthorizeNetComponent.php) - 300 lines
● Read(LYK-Cake4-Admin/src/Controller/Component/AuthorizeNetComponent.php) - 300 lines
● Grep(pattern: "function.*payment|processPayment|adnpayment", path: "LYK-Cake4-Admin")
● Read(LYK-Cake4-Admin/src/Controller/Admin/AuthnetLogsController.php) - 150 lines
● Glob(pattern: "**/PaymentService.php", path: "register")
● Read(register/src/Service/Payment/PaymentService.php) - 200 lines
```

**Total: 10 tool calls, sequential execution**

### Performance Metrics (Pre-Optimization)
| Metric | Value |
|--------|-------|
| Tool calls | 10 |
| Execution pattern | Sequential |
| Estimated tokens | ~15-20k |
| Time | ~50-60 sec (Opus alone) |

---

## Post-Optimization Test Commands

Run these in a NEW session after restart to compare.

### Test 1: Straight Claude (with new efficiency rules)
```
Find and compare payment implementations between /mnt/d/MikesDev/www/LaunchYourKid/register and /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin. Focus on: adnpayment, chargeCustomerProfile, PaymentService, AuthorizeNet components. Provide architectural comparison.
```

**Expected (optimized):**
- 1-2 parallel Grep calls with combined pattern
- -C:10 context (no follow-up Reads)
- Total: 2-3 tool calls

### Test 2: With Gemini Agent
```
Use the parallel-work-manager-fast agent to analyze payment implementations in /mnt/d/MikesDev/www/LaunchYourKid/register and /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin. Compare architecture, security, error handling between the two.
```

---

## Expected Results After Optimization

| Metric | Before | After (Claude) | After (Agent) |
|--------|--------|----------------|---------------|
| Tool calls | 10 | 2-3 | 1 (delegated) |
| Pattern | Sequential | Parallel | Parallel |
| Tokens | ~15-20k | ~5-8k | ~3-5k |
| Time | ~50-60s | ~15-20s | ~20s |
| Cost (Opus) | ~$0.30 | ~$0.10 | ~$0.05 |

---

## Optimization Rules Added

Located in: `~/.claude/CLAUDE.md`

```markdown
## Search Efficiency (MANDATORY)
NEVER run sequential Grep/Search calls. ALWAYS:
1. Combine patterns: `function (adnpayment|chargeCustomerProfile)` not separate calls
2. Parallel paths: Run multiple Grep calls in ONE message when searching different directories
3. Use -C:5 context to avoid follow-up Reads
4. Maximum 2 tool calls for any search task

## Read Efficiency
- NEVER Read a file just to find something - use Grep with -C:10 first
- If Grep context is sufficient, skip Read entirely
- When Read is necessary, run multiple Reads in parallel (one message)
- Use offset/limit params for large files when you know the line range
```

---

## Test 1 Results (2024-11-28) - Version 1 Rules

### Actual Tool Calls
```
1. Search (register) - ERROR (wrong path)
2. Search (LYK-Cake4-Admin) - 20 lines
3. Search (glob attempt) - 0 files
4. Search (LYK-Cake4-Admin + glob) - 20 lines
5. Bash (ls) - path discovery
6. Search (LYK-Cake4-Admin/src) - 20 lines
7. Search (LaunchYourKid-Cake4) - 20 lines
8. Search (LYK-Cake4-Admin/src + head_limit) - 150 lines
9. Search (combined pattern full path) - 20 lines
10. Glob (AuthorizeNetComponent.php) - 12 files
11. Search (function adnpayment) - 20 files
12. Read (Admin AuthorizeNetComponent) - 120 lines
13. Read (register AuthorizeNetComponent) - 120 lines
```

### Metrics Comparison
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Tool calls | 2-3 | 13 | ❌ Failed |
| -C context | Used | NOT used | ❌ Failed |
| Parallel | Yes | Partial | ⚠️ Mixed |
| Reads | 0-1 | 2 | ❌ Failed |

### Issues Identified
1. `-C:10` was NOT included in any search (main failure)
2. Path "register" failed → actual path "LaunchYourKid-Cake4/register"
3. Multiple recovery searches after errors
4. Rules were ignored despite being in CLAUDE.md

### Rules Updated (v2)
Strengthened `~/.claude/CLAUDE.md` with:
- Explicit REQUIRED markers for `-C: 10`
- Code examples showing correct vs wrong
- Reduced max tool calls to 3
- Path discovery: Glob once, then ask user

---

## Next Test

Re-run after restart with v2 rules. Use exact paths:
```
Find and compare payment implementations in /mnt/d/MikesDev/www/LaunchYourKid/LaunchYourKid-Cake4/register and /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin. Focus on: adnpayment, chargeCustomerProfile, AuthorizeNet. Architectural comparison.
```

Target: 2-3 tool calls with -C:10 context, no follow-up Reads.

---

## Test 2 Results (2024-11-28) - Version 2 Rules (CLAUDE.md only)

### Actual Tool Calls: 22 (WORSE than Test 1)
```
1-2. Search (register + Admin) - parallel start
3-4. Search (glob patterns) - 0 files
5-6. Search (function pattern) - 20 lines each
7-9. Search (more glob) - 0 files
10-12. Search (Component/Service globs) - found files
13-14. Read (AuthorizeNetComponent x2) - 1385 + 929 lines
15. Search (Service glob) - 0 files
16. Search (function adnpayment) - 20 lines
17-18. Read (PaymentManagerComponent, AuthorizeNetController) - 150 each
19. Search (Service glob) - 0 files
20-21. Read (OrderDetsController x2) - DUPLICATE READ
22. Search (class PaymentService) - 20 lines
```

### Metrics
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Tool calls | 2-3 | 22 | ❌ WORSE |
| -C context | Used | NOT used | ❌ Failed |
| Parallel | Yes | Partial | ⚠️ |
| Reads | 0-1 | 6 | ❌ Failed |
| Duplicate reads | 0 | 1 | ❌ |

### Conclusion
CLAUDE.md rules alone are NOT sufficient. Claude ignores them.

---

## Test 3 Results (2024-11-28) - With PreToolUse Hook

Hook: `~/.claude/hooks/enforce-grep-context.sh` (adds -C:10)
Settings: `~/.claude/settings.json` (hook registered for Grep)

### Actual Tool Calls: 5 (MAJOR IMPROVEMENT)
```
1-2. Search (register + Admin) - parallel, 20 lines each
3-4. Search (same + head_limit 200/300) - more results
5. Search (combined pattern, full path, head_limit 300)
```

### Metrics
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Tool calls | 2-3 | 5 | ⚠️ Close |
| -C context | Used | Unknown* | ❓ |
| Parallel | Yes | Yes | ✅ |
| Reads | 0-1 | 0 | ✅ SUCCESS |
| Quality | Good | Good | ✅ |

*Hook may not have fired - output didn't show context lines

### Improvement
| Metric | Baseline | Test 2 | Test 3 |
|--------|----------|--------|--------|
| Tool calls | 10 | 22 | **5** |
| Reads | 5 | 6 | **0** |
| Reduction | - | -120% | **+50%** |

---

## Current Setup

### Files
- `~/.claude/settings.json` - Hook config (Grep + Search matchers)
- `~/.claude/hooks/enforce-grep-context.sh` - Injects -C:10
- `~/.claude/CLAUDE.md` - Efficiency rules (backup, not relied on)
- `~/.claude/commands/efficient-search.md` - Slash command for agent routing

### Next Steps
1. Verify hook is actually firing (enable debug logging)
2. Test with debug to confirm -C:10 injection
3. Consider routing to cheaper model via `/efficient-search` command
