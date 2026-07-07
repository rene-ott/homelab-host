# Tasks

The single living plan. **Now** = the one thing in flight (≤5 lines). **Next** = ordered shortlist.
**Someday** = unordered ideas. Workflow: pick from Next → write it in Now → build → commit → add a
line to `LOG.md` → clear Now. No status fields, no per-task files. History is `LOG.md` + git.

## Now

- **Per-role enable/disable toggles** — foundation for a future second, minimal host (base OS
  only, no K3s/Flux/wireguard/cockpit/samba/storage) on branch `feature/implement-multi-host-support`.
  - [x] `<role>_enabled` defaults (true) on the 7 toggleable roles; `security`/`firewall` stay
    mandatory, `bootstrap_user` untouched
  - [x] `site.yml`/`verify.yml` gated with `when: <role>_enabled | default(true) | bool`;
    `site.yml` gains a `pre_tasks` dependency-validation assert (Flux requires K3s, Samba
    requires Storage)
  - [x] Role-local dependency guards in `flux_auth`/`flux_bootstrap`/`samba` for tag-scoped runs
  - [x] `teardown-k3s.yml` refuses teardown when `k3s_enabled` is false
  - [ ] Docs (`CLAUDE.md`, `architecture.md`) updated; full verification suite against `atlas`;
    LOG.md entry once shipped
  - Actually onboarding a real second host is deliberately out of scope for this pass — see
    Someday below.

## Next

- **Jellyfin** — Flux app in `homelab-cluster` at `apps/jellyfin/`: `HelmRepository` + `HelmRelease`
  (chart `https://jellyfin.github.io/jellyfin-helm`), own namespace, Traefik ingress
  `jellyfin.apps.<domain>`, `PersistentVolume` for media + config. Needs `*.apps.<domain>` → server IP.

## Someday

- **Onboard a real second host** once one exists — no hostname/machine to provision yet. Add it
  to `inventory/hosts.yml`/`inventory/bootstrap.yml`, write its `inventory/host_vars/<hostname>.yml`
  with the relevant `*_enabled: false` overrides and a trimmed firewall port list, hand-edit its
  SSH alias into `~/.homelab-secrets/ssh/config`, then run `bootstrap-user.yml` → `site.yml` →
  `verify.yml` with `--limit <hostname>`.
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
- **Review workstation Flux-key generation** — now that Flux is optional per host,
  `init-workstation.sh`'s flux-deploy-key/SOPS-age-key steps are worth revisiting on their own
  terms (e.g. should they become skippable if no host will ever run Flux-enabled?). Separate from
  the role-toggle work; not addressed there.
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
