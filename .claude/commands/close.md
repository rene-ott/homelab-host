Close the current task after verification.

Read:

- `CLAUDE.md`
- `docs/planning/TASKS.md`

Inspect the current diff and recent verification output in the conversation.

Do not commit unless explicitly asked.

Return:

1. Whether anything blocks commit
2. Concise diff summary
3. A commit message with no `Co-Authored-By`, Claude reference, AI attribution, or AI trailer
4. The exact `TASKS.md` edit that clears `## Now`
5. Any follow-up items that should be added to `## Someday`, only if they are genuinely not already there

Rules:

- Do not create or update `LOG.md`.
- Do not recreate `docs/architecture.md`.
- Do not invent shipped history outside git.
- Do not clear `## Now` unless verification has passed.
- Do not start the next task.