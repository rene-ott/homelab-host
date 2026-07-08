# Tasks

The single living plan. **Now** = the one thing in flight (≤5 lines). **Next** = ordered shortlist.
**Someday** = unordered ideas. Workflow: pick from Next → write it in Now → build → commit → add a
line to `LOG.md` → clear Now. No status fields, no per-task files. History is `LOG.md` + git.

## Now

- **Wire `scripts/lib/paths.sh` into `init-workstation.sh` + inventory** — rewrote
  `scripts/init-workstation.sh` into 5 steps (base dirs always created; host alias + SSH config
  per-host merge/replace; ansible key; flux key; sops key), all path-derived from
  `scripts/lib/paths.sh`; moved the per-host secret key paths into new
  `inventory/host_vars/atlas.yml`; updated `CLAUDE.md`/`architecture.md`/`README.md`/`TODO.md`.
  - [x] Script rewritten, `bash -n` clean, per-host `ssh_config.partial` merge logic tested
  - [x] Inventory vars resolve correctly (`ansible -m debug`, `--syntax-check` on both playbooks)
  - [x] Docs updated wherever they described the changed behavior
  - Not yet run for real (interactive, generates real new keys) — left for the user to run
    manually; needs a `bootstrap-user.yml` re-run + new Flux deploy key/age recipient afterward
    since atlas's existing `~/.homelab-secrets/` keys are left in place, not migrated.

## Next

- **Jellyfin** — Flux app in `homelab-cluster` at `apps/jellyfin/`: `HelmRepository` + `HelmRelease`
  (chart `https://jellyfin.github.io/jellyfin-helm`), own namespace, Traefik ingress
  `jellyfin.apps.<domain>`, `PersistentVolume` for media + config. Needs `*.apps.<domain>` → server IP.

## Someday

- **Verify the per-role toggle branch end-to-end against `atlas`** — run `ansible-playbook
  playbooks/site.yml --check --diff` then the full `playbooks/verify.yml` (no `--tags`, i.e.
  every role) against the real server once it's reachable, to confirm the toggle/gating work on
  `feature/implement-multi-host-support` behaves correctly with every role still at its default
  (`true`). Only start this when explicitly told to — `atlas` was unreachable from the
  workstation as of 2026-07-07. Once green, add the `LOG.md` entry.
- **Onboard a real second host** once one exists — no hostname/machine to provision yet. Add it
  to `inventory/hosts.yml`/`inventory/bootstrap.yml`, write its `inventory/host_vars/<hostname>.yml`
  with the relevant `*_enabled: false` overrides and a trimmed firewall port list, hand-edit its
  SSH alias into `~/.homelab/local/ssh_config.partial` (or just re-run `init-workstation.sh`,
  which now prompts for a host alias), then run `bootstrap-user.yml` → `site.yml` → `verify.yml`
  with `--limit <hostname>`.
- **`homelab_profile` convenience var** (e.g. `full` / `base`) — sugar over the individual
  `<role>_enabled` booleans so a base-only host doesn't need to repeat seven `false` lines
  forever. Individual booleans stay the source of truth until this is built; not needed until a
  second or third host profile actually exists.
- **`scripts/cluster.sh` / `scripts/quick-deploy.sh` multi-host support** — both currently
  hardcode tags (`k3s,flux_auth,flux_bootstrap`) and run against the whole `homelab` group with
  no `--limit`. Once a second host shares the inventory: add `--limit <hostname>` support,
  clarify behavior when targeting a base-only host (every tagged role no-ops safely via its
  `_enabled` toggle, but the menu labels currently assume the full stack), and consider splitting
  the script's concerns (e.g. separate `site.sh`/`cluster.sh`/`verify.sh` intents).
- **Finish wiring `scripts/lib/paths.sh` into the remaining scripts** —
  `scripts/init-workstation.sh` and the inventory are done (see `## Now` above / `LOG.md`).
  Still on the old `~/.homelab-secrets`/`~/.homelab-backups` paths: `backup-secrets.sh` (including
  the `SECRET_FILES`/`SRCS`/`DSTS` staging-layout rework), `backup-config.sh`,
  `backup-wireguard.sh`, `wireguard-client.sh`, and `clear-workstation.sh` (per TODO.md's "Known
  blast radius").
- **Monitoring** — Prometheus + Grafana in K3s (`homelab-cluster` repo, `infrastructure/`); Grafana via Traefik
  (HTTPS wildcard already exists).
- **Molecule tests** for the `firewall` role.
- **Inventory SOPS for per-host Ansible secrets** — *Gate: only when a real per-host Ansible
  secret appears (not a workstation key or Kubernetes runtime secret).* Option B from Pass 4: add
  `community.sops` to `requirements.yml`; enable `vars_plugins_enabled =
  host_group_vars,community.sops.sops` in `ansible.cfg`; add `host/.sops.yaml` with a real age
  recipient; create encrypted `inventory/group_vars/homelab/secrets.sops.yml`; rewire the
  `lookup('file', flux_auth_bootstrap_ssh_key_file)` and
  `lookup('file', flux_bootstrap_sops_age_key_file)` calls to inventory vars; preserve
  `no_log: true`. See `inventory/group_vars/homelab/secrets.sops.yml.example` for the template.
