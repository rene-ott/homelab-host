# Tasks

The single living plan. **Now** = the one thing in flight, kept short. **Next** = ordered shortlist.
**Someday** = unordered ideas and parked implementation notes.

Workflow: pick from **Next** → write it in **Now** → build → verify → commit → clear **Now**.

No status fields, no per-task files, no separate changelog. Current intent lives here; shipped history
lives in git.

## Now

- **Per-role enable/disable toggles** — finish the multi-host groundwork on
  `feature/implement-multi-host-support`.
  - [ ] Fold the relevant architecture guidance into `CLAUDE.md`
  - [ ] Add `.claude/commands/{plan,implement,review,close}.md`
  - [ ] Remove `docs/architecture.md` and `docs/planning/LOG.md`
  - [ ] Run full verification against `atlas`
  - [ ] Commit and clear `Now`

## Next

## Someday

- **Onboard a real second host** once one exists — no hostname/machine to provision yet. Add it
  to `inventory/hosts.yml`/`inventory/bootstrap.yml`, write its `inventory/host_vars/<hostname>.yml`
  with the relevant `*_enabled: false` overrides and a trimmed firewall port list, hand-edit its
  SSH alias into `~/.homelab-secrets/ssh/config`, then run `bootstrap-user.yml` → `site.yml` →
  `verify.yml` with `--limit <hostname>`.