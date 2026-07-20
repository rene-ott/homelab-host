Promote the next task into `## Now`. This is the *only* action — do not scope,
implement, decompose, or commit.

Read `docs/planning/TASKS.md`, then:

1. If `## Now` is not empty, stop and report what is in flight — refuse to promote
   onto a non-empty `Now` (one thing at a time).
2. Take the **top** item of `## Next` (top = highest priority) and move it verbatim
   into `## Now`, removing it from `## Next`. Preserve any classification or
   structure an earlier `/assess` added; do not add a sub-checklist here.
3. If `## Next` is empty, stop and report it — do not auto-pull from `## Someday`.

Show the resulting `## Now` and confirm the `TASKS.md` edit.
