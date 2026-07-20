Run the **Review** phase from the workflow contract in `CLAUDE.md`. Do not edit files.

Read the plan's declared `PRIMARY` type and walk its checklist:

- **refactor** → behavior unchanged: idempotent, `--check` parity, `verify.yml` still green
- **new feature** → fully wired: toggle, `site.yml` + `verify.yml` in order, ports via
  `firewall`, verify task present
- **bugfix** → the bug is fixed *and* a check would catch its regression
- **architectural** → the changed contract is updated everywhere relied on; **always
  surface**: did a documented invariant in `CLAUDE.md` change, and is `CLAUDE.md`
  updated to match? (mandatory to check; human decides)
- **docs** → internally consistent with the code

Then, for every type:

1. Diff implements only the current `## Now` item (or its current box) — no scope
   creep into `## Next` / `## Someday`
2. No violation of `CLAUDE.md` invariants (ports, K3s-apps, secrets, always-on roles,
   variable naming)
3. No workflow-trap hit (`--limit`, `check_mode`, `run_once`, disabled-role asserts)
4. Whether `/verify` has run and what it returned

Return `OK to close` or `Needs changes`, then blockers, non-blocking notes, and — if
`/verify` hasn't run — a note to run it before `/close`.
