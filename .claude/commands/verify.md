Run the **Verify** phase from the workflow contract in `CLAUDE.md`. Do not edit files.

**Execute the verification the plan specified** — do not re-derive it. If no plan
verification exists for the current box, say so and stop (run `/scope` first).

Run each specified command, in the plan's order, stopping to report on first failure.
For the current box, that is the recipe(s) for its touched component(s):

- roles → `verify.yml` (+ tags) and/or `--check --diff --limit <env>`
- inventory → `--check --diff --limit <env>`
- scripts → `shellcheck` + dry-run each touched script
- CLAUDE.md/TASKS.md → consistency read against the code
- on-disk layout → migration/restore dry run for existing data

Rules:

- Every `site.yml`/`verify.yml` invocation MUST carry `--limit prod` or `--limit staging`.
- A step that cannot run from here (no reachable host, workstation-only) is
  **DEFERRED** with the reason — never silently skipped, never reported as passed.
- Report each step PASSED / FAILED / DEFERRED with the exact command used.

Return `VERIFIED` (all runnable steps passed, deferrals named) or `FAILED` (with the
failing step). `/close` reads this result.
