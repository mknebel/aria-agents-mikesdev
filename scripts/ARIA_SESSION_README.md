# ARIA Session Memory Management

Session memory system for maintaining conversation history across `aria route` calls, allowing LLMs to have context from previous interactions.

## Overview

The ARIA Session system provides:

- **Persistent conversation history** across CLI calls
- **Session switching** for parallel conversations
- **Automatic token tracking** to fit context within limits
- **JSON lines format** for easy parsing and integration
- **Metadata tracking** (timestamps, turn counts, token usage)

## Quick Start

```bash
# Create new session
/home/mike/.claude/scripts/aria-session.sh new

# View current session
/home/mike/.claude/scripts/aria-session.sh show

# List all sessions
/home/mike/.claude/scripts/aria-session.sh list

# Switch sessions
/home/mike/.claude/scripts/aria-session.sh switch session_1764919970_hy66or
```

## Session Storage

Sessions are stored in `~/.claude/cache/sessions/`:

```
~/.claude/cache/sessions/
├── current                       # Symlink to active session file
├── session_1764919970_hy66or.jsonl   # Conversation history (JSON lines)
├── session_1764919970_hy66or.meta    # Session metadata
├── session_1764919986_fglktw.jsonl
└── session_1764919986_fglktw.meta
```

### JSONL Format

Each conversation is stored as JSON lines (one object per line):

```json
{"role": "user", "content": "What is 2+2?", "timestamp": 1764919978, "model": "gpt-5.1"}
{"role": "assistant", "content": "2+2 equals 4.", "timestamp": 1764919978, "model": "gpt-5.1"}
{"role": "user", "content": "Now multiply by 3", "timestamp": 1764919980, "model": "gpt-5.1"}
{"role": "assistant", "content": "4 * 3 = 12", "timestamp": 1764919980, "model": "gpt-5.1"}
```

### Metadata Format

Session metadata is stored as JSON:

```json
{
  "id": "session_1764919970_hy66or",
  "created": 1764919970,
  "modified": 1764919980,
  "turn_count": 4,
  "token_count": 248
}
```

## CLI Commands

### `aria-session.sh new`
Create a new session and set as current.

```bash
$ ./aria-session.sh new
Created new session: session_1764919970_hy66or
```

### `aria-session.sh current` / `aria-session.sh cur`
Show the current session ID.

```bash
$ ./aria-session.sh current
session_1764919970_hy66or
```

### `aria-session.sh list` / `aria-session.sh ls`
List all sessions with metadata.

```bash
$ ./aria-session.sh list
Available Sessions:
────────────────────────────────────────────────────────────────
* session_1764919970_hy66or                 Turns:   4  Created: 2025-12-05 01:33:06
  session_1764919986_fglktw                 Turns:   0  Created: 2025-12-05 01:33:18
────────────────────────────────────────────────────────────────
Total: 2 sessions (* = current)
```

### `aria-session.sh show` / `aria-session.sh view`
Display the current session's conversation history with formatting.

```bash
$ ./aria-session.sh show
Session: session_1764919970_hy66or
Turns: 4  |  Tokens: 248
────────────────────────────────────────────────────────────────

User:
  What is 2+2?