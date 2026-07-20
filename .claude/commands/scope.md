Run the **Scope** phase from the workflow contract in `CLAUDE.md`. Read-only, in
Plan Mode. Do not edit files.

Return, for the current `## Now` item:

1. The item (and its sub-checklist, if present) — which box is next
2. **Classification** — `PRIMARY: refactor | new feature | bugfix | architectural | docs`
   and `TOUCHES: <components>` (roles, inventory, scripts, CLAUDE.md, on-disk)
3. Explicitly in-scope work
4. Explicitly out-of-scope work, including nearby tempting work
5. Files likely to change
6. Safest implementation order
7. **Verification plan** — the exact command(s) per touched component (see the
   contract's component→recipe table). A plan with no verification section is invalid.

Then the outcome. **Prefer decompose:**

- `SCOPE: proceed` — the whole change is one slice verified one way. Justify why it
  needs no split.
- `SCOPE: decompose` — more than one recipe applies → propose an ordered `- [ ]`
  sub-checklist, one box per component/recipe, each independently verifiable.
- `SCOPE: split` — this is really two *items*; propose rewriting `Now` and refiling
  the extra part to `Next`/`Someday`.
