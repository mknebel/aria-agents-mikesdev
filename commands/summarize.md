---
description: Summarize current session to reduce context size
allowed-tools: Read, Bash
---

Create a concise summary of this session's work for context compaction.

Review what has been accomplished in this session and create a summary that captures:

1. **Tasks Completed**: List what was done
2. **Files Modified**: Key files that were changed
3. **Decisions Made**: Important choices and their rationale
4. **Current State**: Where things stand now
5. **Next Steps**: What remains to be done (if any)

Format the summary as a compact markdown block that can be used to restore context in a new session.

After creating the summary, tell the user:
- They can copy this summary
- Start a new session with `/clear` or open a new terminal
- Paste the summary to restore context
- This reduces token usage by ~70-90%
