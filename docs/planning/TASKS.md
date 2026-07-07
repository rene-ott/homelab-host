# Tasks

The single living plan. **Now** = the one thing in flight (≤5 lines). **Next** = ordered shortlist.
**Someday** = unordered ideas. Workflow: pick from Next → write it in Now → build → commit → add a
line to `LOG.md` → clear Now. No status fields, no per-task files. History is `LOG.md` + git.

## Now

- **WireGuard remote-access VPN** — `wireguard` role (server keypair, `wg0.conf` from
  `wireguard_peers`), UDP 51820 in firewall, split-tunnel `10.10.10.0/24`.
  - [x] `roles/wireguard` + firewall/site.yml/verify.yml wiring
  - [x] `scripts/wireguard-client.sh` (workstation + phone keys/config, QR via qrencode)
  - [ ] Bootstrap (empty keys) → server pubkey → client script → fill `wireguard_peers` → re-run
  - [x] docs/architecture.md + CLAUDE.md updated; LOG.md entry once shipped; router port-forward is a manual step

## Next

- **Jellyfin** — Flux app in `homelab-cluster` at `apps/jellyfin/`: `HelmRepository` + `HelmRelease`
  (chart `https://jellyfin.github.io/jellyfin-helm`), own namespace, Traefik ingress
  `jellyfin.apps.<domain>`, `PersistentVolume` for media + config. Needs `*.apps.<domain>` → server IP.

## Someday

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
