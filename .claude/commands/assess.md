Run the **Assess** phase from the workflow contract in `CLAUDE.md`. Read-only —
investigate and recommend, change no code. Run in Plan Mode.

Use when a `Next`/`Someday` item is a *question*, not a decided change. If more than
one item could be meant, ask which; otherwise assess the named item.

1. **Best-practice judgment first.** Decide whether the change is sound before
   detailing it — research idiomatic Ansible / this repo's conventions (read the
   relevant roles, `CLAUDE.md`). State clearly: good idea or not?
2. **Options and tradeoffs.** If more than one reasonable approach, lay them out and
   recommend one.
3. **If recommended → classify and enumerate.** Declare `PRIMARY` and `TOUCHES` (per
   the contract), then list the concrete work: files/roles, rules affected, bugs
   fixed or risked, `CLAUDE.md` edits implied — enough to be scope-ready.
4. **If not recommended → say why**, so the question is settled.

End with a `TASKS.md` edit proposal (do not apply unless asked):

- **recommended** → rewrite the stub into a decided item in the house style (title +
  one-paragraph intent + rationale), placed in `Next` or fleshed out in `Someday`.
- **not recommended** → propose removing it or annotating it decided-against.

Result: `ASSESS: recommended | not recommended | needs input`. Do not implement,
commit, or move the item into `## Now`.
