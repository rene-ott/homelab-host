Plan the current task. This command is intended to be run only while Claude Code is in plan mode.

Read:

- `CLAUDE.md`
- `docs/planning/TASKS.md`

Do not edit files.

Return:

1. Current `## Now` task
2. Explicitly in-scope work
3. Explicitly out-of-scope work, including nearby tempting work
4. Files likely to change
5. Safest implementation order
6. Exact verification commands
7. Risks or decisions for the human

Repo rules:

- `TASKS.md` is current/future intent, not shipped history.
- Git is shipped history.
- Do not create `LOG.md`, changelogs, `architecture.md`, per-task files, migration plans, or TODO inventories.
- Do not start anything from `## Next` or `## Someday` unless explicitly asked.
- Do not edit, commit, or clear `## Now` during planning.