# How Justfile Commands Are Loaded in Every Session

## Automatic Loading

Claude Code automatically loads these files at **every session start**:

1. **`/home/mike/.claude/CLAUDE.md`** - Global instructions (all projects)
2. **Project-specific CLAUDE.md** files in current working directory hierarchy

## What Happens at Session Start

```
Session Start
     ↓
Claude Code loads CLAUDE.md files
     ↓
System reminder injected into context:
"As you answer the user's questions, you can use the following context:
 Contents of /home/mike/.claude/CLAUDE.md (user's private global instructions)
 Contents of /path/to/project/CLAUDE.md (project instructions)"
     ↓
Claude sees: ⚠️ CRITICAL: Use justfile commands 100% of the time
     ↓
Claude follows instructions (uses just commands by default)
```

## Verification

You can verify this is working by looking at the **system-reminder** at session start:

```xml
<system-reminder>
As you answer the user's questions, you can use the following context:
# claudeMd
Codebase and user instructions are shown below...

Contents of /home/mike/.claude/CLAUDE.md (user's private global instructions for all projects):
[Your optimized CLAUDE.md content appears here]
</system-reminder>
```

## Making It Even More Visible

### Option 1: Session Start Hook (Recommended)

Create a hook that runs at session start to remind Claude:

**File: `~/.config/claude-code/hooks/session-start.sh`**
```bash
#!/bin/bash
echo "⚡ Justfile-first workflow active. Run 'just --list' to see commands."
echo "📋 Ultra-short aliases: cx, st, ci, co, t, l, f, r"
```

### Option 2: Add to Shell Prompt

Add to your `.bashrc` or `.zshrc`:
```bash
# Show justfile reminder when entering project directories
cd() {
    builtin cd "$@"
    if [ -f "justfile" ]; then
        echo "⚡ Justfile detected! Run: just --list"
    fi
}
```

### Option 3: Add Banner to CLAUDE.md (Already Done!)

We already added this at the top:
```markdown
**⚠️ CRITICAL: This file is loaded at every session start. Use these commands 100% of the time.**
```

## Current State

✅ **Global CLAUDE.md** - Loaded automatically, includes:
   - Quick reference table with aliases
   - Subagent instructions
   - Token savings comparison
   - Ultra-short alias list

✅ **Project CLAUDE.md files** - Loaded for each project:
   - LaunchYourKid/CLAUDE.md
   - LaunchYourKid-Cake4/CLAUDE.md
   - BuyUSAFirst-Cake4/CLAUDE.md (if exists)
   - VerityCom/CLAUDE.md (if exists)

✅ **Justfile aliases** - Available in all projects:
   - Global: cx, st, ci, co, lg, br, u, p, f, r, t, s
   - Project: cx, st, ci, co, lg, br, l, t, f, r, + project-specific

## Testing in New Session

1. Start a new Claude Code session
2. Look for system-reminder with CLAUDE.md content
3. Claude should automatically use `just` commands
4. Verify by asking: "How should I search for code?" - Answer should mention `just cx`

## Why This Works 100% of the Time

1. **CLAUDE.md is injected into every session** (system-reminder)
2. **Instructions marked as CRITICAL** (override default behavior)
3. **Quick reference at top** (first thing Claude sees)
4. **Subagent instructions** (all spawned agents get the same rules)
5. **Ultra-short aliases** (easier to use = higher adoption)

## If Instructions Aren't Being Followed

Check:
1. Is `/home/mike/.claude/CLAUDE.md` readable? `cat ~/.claude/CLAUDE.md`
2. Does session show system-reminder? Look for `<system-reminder>` at start
3. Are you in a project directory? `pwd` and check for project CLAUDE.md
4. Does `just --list` work? Verifies justfile is accessible

## Expected Behavior in New Sessions

**User:** "Search for cart-related code"

**Claude (correct):** "I'll use `just cx \"cart\"` to search..."

**Claude (incorrect):** "Let me use grep to search..." ❌

The CLAUDE.md ensures Claude always uses justfile commands first.
