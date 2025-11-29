## Search Efficiency (MANDATORY - NEVER IGNORE)

EVERY Grep/Search call MUST include:
```
-C: 10          ← REQUIRED, never omit
output_mode: "content"  ← REQUIRED
glob: "*.php"   ← when searching code
```

Rules:
1. Combine patterns: `(term1|term2|term3)` - ONE search, not multiple
2. Parallel paths: Multiple Grep calls in ONE message for different directories
3. Maximum 3 tool calls for any search task
4. If path fails, Glob ONCE to find it - don't retry variations

CORRECT:
```
Grep(pattern: "(adnpayment|chargeCustomerProfile)", path: "/full/path", -C: 10, output_mode: "content", glob: "*.php")
```

WRONG (missing -C - will need follow-up Reads):
```
Search(pattern: "...", path: "...", output_mode: "content")
```

## Read Efficiency
- NEVER Read after searching - -C:10 context should be enough
- If you must Read, run multiple in parallel (one message)
- Use offset/limit for large files when you know line range
- For files >500 lines: use limit:200 centered on area of interest

## Search Result Limits
- Use head_limit:50 for discovery searches (finding files)
- Use head_limit:100 for content searches (reading code)
- Use output_mode:"files_with_matches" for "what files contain X" questions
- Use output_mode:"content" only when you need the actual code

## Edit Efficiency
- Use MultiEdit for 2+ changes in same file (one call vs multiple)
- Batch related file changes in parallel Edit calls (one message)
- Don't Read before Write if creating new file or full replacement

## Agent Routing (Cost Optimization)
- Simple searches/discovery → Explore agent (faster, cheaper)
- Complex analysis → Main Claude (better reasoning)
- Bulk file operations → parallel-work-manager agents

## Path Discovery
- Use absolute paths
- If relative fails → Glob ONCE → ask user if still not found

## Bash Efficiency
- Chain related commands with && in ONE Bash call
- Pre-check requirements before operations that might fail (e.g., git config before commit)
- Use absolute paths to avoid cd (working directory resets after each call)
- For git workflows: init + config + add + commit + push in ONE chained command
- WRONG: 5 sequential Bash calls for git operations
- RIGHT: `git add -A && git commit -m "msg" && git push` in one call
