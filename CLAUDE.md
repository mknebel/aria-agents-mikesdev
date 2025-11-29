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

## Path Discovery
- Use absolute paths
- If relative fails → Glob ONCE → ask user if still not found
