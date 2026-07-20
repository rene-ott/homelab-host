Run the **Close** phase from the workflow contract in `CLAUDE.md`. Do not commit
unless explicitly asked.

**Refuse to close unless the latest `/verify` returned `VERIFIED` AND no edits were
made since that verify ran** (deferred steps allowed only with their stated reason).
If verification is missing or stale (any change touched the tree after it), say so
and stop — re-run `/verify` first.

Then inspect the current diff and return:

1. Whether anything blocks commit
2. A concise diff summary
3. A commit message — no `Co-Authored-By`, Claude reference, or AI trailer
4. The exact `TASKS.md` edit:
   - sub-checklist with boxes remaining → check off the completed box, leave the item in `Now`
   - last box, or no checklist → clear `Now` entirely
5. Any genuinely-new follow-up for `## Someday` (only if not already there)

Do not clear `Now` or check a box unless verification passed. Do not start the next item.
