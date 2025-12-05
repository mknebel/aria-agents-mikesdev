# Tools Quick Reference

## CLI Tools Priority
```yaml
codex:  FREE (OpenAI subscription) - complex code generation
gemini: FREE (Google subscription) - large context analysis (1M tokens)
ctx:    FREE (local) - semantic search → $ctx_last
/lookup: FREE (local) - instant index lookup
ai.sh:  ~$0.001 - OpenRouter presets
```

## Gemini CLI

### Installation
```bash
npm install -g @google/gemini-cli
```

### Usage
```bash
# Interactive mode
gemini

# Single prompt
gemini --prompt "Your prompt"

# Attach files (recommended)
gemini "Analyze this code" @src/Controller/*.php

# Glob patterns work
gemini "Find security issues" @src/**/*.php

# Pipe content
cat file.php | gemini "Explain this"
```

### Tips
- 1M token context = ~750K words
- Free tier: 60 req/min, 1000/day
- Use `@filename` to attach files directly

## Codex CLI

### Installation
```bash
npm install -g @openai/codex
```

### Usage Modes
```bash
# Interactive (asks permission)
codex "Implement JWT auth"

# Auto-edit (reads/writes files, asks for commands)
codex --approval-mode auto-edit "Add validation"

# Full-auto (completely autonomous, sandboxed)
codex --approval-mode full-auto "Build shopping cart"

# Quiet mode (CI/scripting)
codex -q "Run tests and fix failures"

# With web search
codex --search "Implement OAuth2 best practices"

# Resume last session
codex resume --last
```

### Best For
- Complex multi-file implementations
- Autonomous feature development
- Test-driven development loops
- Debugging with auto-fix

## ai.sh (OpenRouter)

```bash
# Presets
ai.sh fast "quick question"     # DeepSeek, cheapest
ai.sh tools "implement X"       # Tool-use models
ai.sh qa "review this code"     # QA/Doc preset
ai.sh browser "test login"      # Browser automation

# Output saved to /tmp/claude_vars/openrouter_last
```

## Variable References

```bash
$ctx_last          # Last context search
$llm_response_last # Last LLM response
$grep_last         # Last grep result
$codex_last        # Last codex output
$gemini_last       # Last gemini output

# Usage
llm codex "implement based on @var:ctx_last"
```

## Search Priority
```
1. /lookup ClassName     # Instant from index
2. ctx "semantic query"  # Local semantic search
3. Grep (only if above fail)
```
