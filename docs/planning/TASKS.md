# Tasks

The single living plan. **Now** = the one thing in flight, kept short. **Next** = ordered shortlist.
**Someday** = unordered ideas and parked implementation notes.

Workflow: pick from **Next** → write it in **Now** → build → verify → commit → clear **Now**.

No status fields, no per-task files, no separate changelog. Current intent lives here; shipped history
lives in git.

## Now

- **Collapse `flux_preflight` + `flux_bootstrap` into one `flux` role.** Preflight is a precondition
  of bootstrap, not a separate concern: the two `_enabled` toggles cannot move independently, the
  `flux-system` namespace probe is duplicated verbatim in both roles, and CLAUDE.md's variable-naming
  rule needs a carve-out ("vars shared by the two flux roles") just to accommodate the split. One
  role, one `flux_enabled`, one `flux` tag, with `tasks/preflight.yml` + `tasks/main.yml` +
  `tasks/verify.yml`. Each precondition is gated by the mutation it protects, so a converged host
  makes no network call and runs no localhost asserts. Fixes two bugs on the way: `run_once` on a
  task whose `when` reads a per-host register evaluates against the first host only (so a no-limit
  run skipped the reachability gate for `atlas-stg` whenever `atlas` was already bootstrapped), and
  read-only `command` probes without `check_mode: false` skip under `--check` while registering a
  fabricated `rc: 0` — so a dry run against a never-bootstrapped host read "flux-system exists" and
  reported nothing to do. Drops the interactive `pause` for a fail-fast assert that prints the
  deploy public key and the GitHub URL, making `site.yml` unattended-safe.

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