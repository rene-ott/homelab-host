# Tasks

The single living plan. **Now** = the one thing in flight, kept short. **Next** = ordered shortlist.
**Someday** = unordered ideas and parked implementation notes.

Workflow: pick from **Next** → write it in **Now** → build → verify → commit → clear **Now**.

No status fields, no per-task files, no separate changelog. Current intent lives here; shipped history
lives in git.

## Now

## Next

## Someday

- **Use a real "already bootstrapped" signal for the `flux` role.** The role gates bootstrap on
  `flux-system` namespace existence, but the role *creates* that namespace itself (early, so the
  `sops-age` secret can be applied before bootstrap and Flux can decrypt on first reconcile). A
  `flux bootstrap git` that dies mid-flight — GitHub outage, deploy key loses write access — leaves
  the namespace behind, so the next run reads "already bootstrapped" and skips forever; recovery
  needs a manual `kubectl delete ns flux-system`. Gate on
  `k3s kubectl -n flux-system get kustomization flux-system` instead, which only a completed
  bootstrap creates.

- **Finish the `~/.homelab` migration for the backup helpers.** `backup-secrets.sh`,
  `backup-config.sh`, `backup-wireguard.sh`, and `wireguard-client.sh` still read the legacy
  `~/.homelab-secrets`/`~/.homelab-backups` paths and hardcode `REMOTE_HOST=atlas`. Rewire them
  onto `scripts/lib/paths.sh` (`HL_*`, per-host `HL_HOST`), then delete the old dirs and remove the
  temporary WireGuard-off-limits rule from CLAUDE.md. (The secrets/backups redesign, the per-host
  Ansible var rewrite, and `init-workstation.sh` are already migrated.)

- **Onboard a real second host** once one exists — no hostname/machine to provision yet. Add it
  to `inventory/hosts.yml`/`inventory/bootstrap.yml`, write its `inventory/host_vars/<hostname>.yml`
  with the relevant `*_enabled: false` overrides and a trimmed firewall port list, run
  `HL_HOST=<hostname> ./scripts/init-workstation.sh` to create its `~/.homelab/local/<hostname>/`
  keys and SSH alias, then run `bootstrap-user.yml` → `site.yml` → `verify.yml` with
  `--limit <hostname>`.

- **Re-encrypt the WireGuard backup** — `backup-wireguard.sh` currently writes plaintext
  keys under `~/.homelab-backups/wireguard/` as a temporary get-the-data measure. Restore
  `age -p` encryption (and a matching decrypt/restore path) once the data is captured, or
  fold WireGuard client secrets into `backup-secrets.sh`'s encrypted archive.