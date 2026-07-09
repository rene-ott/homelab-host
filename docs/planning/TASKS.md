# Tasks

The single living plan. **Now** = the one thing in flight, kept short. **Next** = ordered shortlist.
**Someday** = unordered ideas and parked implementation notes.

Workflow: pick from **Next** → write it in **Now** → build → verify → commit → clear **Now**.

No status fields, no per-task files, no separate changelog. Current intent lives here; shipped history
lives in git.

## Now

- **Architecture-review follow-ups** — add `tasks/verify.yml` for the mandatory `security` and
  `firewall` roles and wire them into `playbooks/verify.yml`; hoist the SOPS age-key assert to
  the top of `flux_bootstrap` (validate before mutate) and align its namespace check's
  `KUBECONFIG`; derive `samba_force_uid`/`_gid` from `storage_owner`/`storage_group`; rename
  `flux_preflight` (was `flux_auth`) — role dir, toggle, registers, docs; drop `run_once` from
  the WireGuard public-key display so each host prints its own key.

## Next

## Someday

- **Redesign `~/.homelab-secrets/` and `~/.homelab-backups/` folder structure** to be more
  role-oriented, given roles are enabled per-host on a role basis (multihost context).
- **Rewrite the Ansible code to match** the redesigned secrets/backups folder structure.
- **Consolidate the `scripts/*.sh` helpers** — merge overlapping scripts and define shared constants
  / library paths in one place, done with multihost in mind (`REMOTE_HOST` is currently hardcoded to
  `atlas` in the backup scripts; the SSH-alias helper in `init-workstation.sh` is a first step).

- **Onboard a real second host** once one exists — no hostname/machine to provision yet. Add it
  to `inventory/hosts.yml`/`inventory/bootstrap.yml`, write its `inventory/host_vars/<hostname>.yml`
  with the relevant `*_enabled: false` overrides and a trimmed firewall port list, hand-edit its
  SSH alias into `~/.homelab-secrets/ssh/config`, then run `bootstrap-user.yml` → `site.yml` →
  `verify.yml` with `--limit <hostname>`.

- **Re-encrypt the WireGuard backup** — `backup-wireguard.sh` currently writes plaintext
  keys under `~/.homelab-backups/wireguard/` as a temporary get-the-data measure. Restore
  `age -p` encryption (and a matching decrypt/restore path) once the data is captured, or
  fold WireGuard client secrets into `backup-secrets.sh`'s encrypted archive.