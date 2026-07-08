# CLAUDE.md

Guidance for Claude Code in this repo. This is the single rules and architecture file for the
host Ansible project.

## Repo Purpose

`homelab-host` is the Ansible project for the Debian homelab server and its K3s platform. It
configures the OS layer, installs K3s, and bootstraps Flux CD once.

Kubernetes apps do **not** live in this repo. Apps, HelmReleases, Kustomizations, and Kubernetes
runtime secrets live in the separate `rene-ott/homelab-cluster` GitOps repo. Flux watches that repo
and deploys workloads automatically after bootstrap.

## Repo Map

- Run Claude Code and Ansible from the repo root. `ansible.cfg` is at the root.
- Ansible code lives at the repo root: `inventory/`, `roles/`, `playbooks/`, `ansible.cfg`.
- Planning lives in `docs/planning/TASKS.md`.
- Reusable Claude Code workflows live in `.claude/commands/`.
- There is no `docs/architecture.md`, no `LOG.md`, no per-task files, and no separate changelog.
- Current/future intent lives in `TASKS.md`; shipped history lives in git.

## Task Workflow

`docs/planning/TASKS.md` is the single living plan:

- `## Now` — the one thing in flight, kept short
- `## Next` — ordered shortlist
- `## Someday` — unordered ideas and parked implementation notes

Loop:

1. Pick one item from `Next`
2. Write it into `Now`
3. Build only that item
4. Verify it
5. Commit it
6. Clear `Now`

Do not create status fields, per-task files, migration plans, TODO inventories, changelogs, or
additional planning documents.

## Claude Code Operating Mode

Work in small, bounded passes.

Before editing, read this file and `docs/planning/TASKS.md`. Treat `TASKS.md` as the only planning
source. Implement only the current `## Now` item unless the human explicitly asks otherwise.

Use four modes:

1. **Scope** — summarize the current task, scope, non-scope, likely files, safe order, and verification.
2. **Implement** — make the smallest coherent change for `Now` only.
3. **Review** — inspect the diff for scope creep, rule violations, architecture issues, and missing verification.
4. **Close** — after verification, suggest a commit message and the `TASKS.md` edit that clears `Now`.

Do not commit, clear `Now`, or start the next task unless explicitly asked.

Commit messages must not contain `Co-Authored-By`, Claude references, AI attribution, or any other
AI-attribution trailer.

## Core Ansible Rules

1. **One role per concern.** Do not merge unrelated services into one role.
2. **Firewall ports in group vars only.** Host-level ports live in `inventory/group_vars/homelab/vars.yml`. No role except `firewall` may open ports.
3. **K3s platform is not K3s apps.** This repo installs K3s and bootstraps Flux only. App changes go to `homelab-cluster`.
4. **K3s apps use ingress.** Apps are exposed through Traefik on 80/443. Do not open app-specific host ports.
5. **No plaintext secrets in repo.** Kubernetes runtime secrets live as SOPS-encrypted manifests in `homelab-cluster`.
6. **No speculative config.** Inventory and defaults should contain only variables used by implemented roles.
7. **Bootstrap access is separate.** `bootstrap-user.yml` provisions the `ansible` OS user; `site.yml` runs after that as `ansible` by key.
8. **Private SSH keys stay on the workstation.** Deploy public keys only, except the documented Flux deploy-key bootstrap carve-out.
9. **`security` and `firewall` are mandatory.** They are not toggleable.
10. **Every other `site.yml` role is toggleable per host.** Each toggleable role has `<role>_enabled` in its own `defaults/main.yml`, defaulting to `true`.

## Role Map

| Role | Concern | Toggle |
|------|---------|--------|
| `bootstrap_user` | Bootstrap-only creation of the `ansible` OS user, public key, and passwordless sudo | not part of `site.yml` |
| `security` | SSH hardening, fail2ban, unattended upgrades | always on |
| `firewall` | UFW rules from `inventory/group_vars/homelab/vars.yml` | always on |
| `wireguard` | Split-tunnel VPN on UDP 51820, overlay `10.10.10.0/24` | `wireguard_enabled` |
| `cockpit` | Web management UI on port 9090 | `cockpit_enabled` |
| `storage` | Shared host directory roots under `/srv` | `storage_enabled` |
| `samba` | Guest read-write SMB shares for media/misc | `samba_enabled`, requires `storage_enabled` |
| `k3s` | K3s platform install and node readiness | `k3s_enabled` |
| `flux_auth` | Flux deploy-key checks and GitHub registration pause | `flux_auth_enabled`, requires `k3s_enabled` |
| `flux_bootstrap` | Flux bootstrap and SOPS age Secret injection | `flux_bootstrap_enabled`, requires `k3s_enabled` |

`site.yml` and `verify.yml` must gate toggleable roles with:

```yaml
when: <role>_enabled | default(true) | bool
```

`flux_auth` and `flux_bootstrap` require `k3s_enabled: true`. `samba` requires `storage_enabled: true`.
Both top-level dependency validation and role-local guards should fail fast for inconsistent
combinations, including tag-scoped runs.

## Execution Order

`bootstrap_user` runs separately via `playbooks/bootstrap-user.yml`.

`playbooks/site.yml` applies roles in this order:

1. `security`
2. `firewall`
3. `wireguard`
4. `cockpit`
5. `storage`
6. `samba`
7. `k3s`
8. `flux_auth`
9. `flux_bootstrap`

`playbooks/verify.yml` is read-only and should report `changed=0` on a healthy system.

## Access Model

A human admin user is created during Debian install. Before touching the server, run
`scripts/init-workstation.sh` on the workstation. It creates `~/.homelab-secrets/`, generates the
Ansible SSH key, Flux deploy key, and SOPS age key, and writes the SSH alias.

First server run:

```bash
ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u <admin> --ask-pass --ask-become-pass
```

Every later run:

```bash
ansible-playbook playbooks/site.yml
```

The `ansible` user must use key-only SSH and passwordless sudo. Keep the human admin as a break-glass
password login.

## Secrets Model

Local workstation secrets live under `~/.homelab-secrets/` and are never committed.

Important paths:

- `~/.homelab-secrets/ssh/ansible`
- `~/.homelab-secrets/ssh/flux-deploy`
- `~/.homelab-secrets/ssh/config`
- `~/.homelab-secrets/age/homelab.agekey`
- `~/.homelab-secrets/wireguard/`

The Flux deploy key is the only private-key carve-out: `flux_bootstrap` may stage it temporarily on
the server with `0600` permissions and `no_log: true`, run `flux bootstrap git`, then delete the temp
file in an `always` block. This carve-out does not apply to `authorized_keys`.

The SOPS age private key is injected into the cluster as `flux-system/sops-age` by `flux_bootstrap`.
Ansible should fail fast with a clear remediation message if the age key is missing.

Kubernetes runtime secrets such as Cloudflare tokens live only in `homelab-cluster` as
SOPS-encrypted manifests.

## K3s and Flux Model

Ansible installs the K3s platform and bootstraps Flux CD once.

After bootstrap:

- Flux watches `rene-ott/homelab-cluster`
- app changes are commits in `homelab-cluster`
- this repo does not manage app manifests, HelmReleases, or app namespaces

Flux bootstrap uses `flux bootstrap git` over SSH with a repo deploy key, not a GitHub PAT.

## Port Model

All host-level firewall ports are declared only in `inventory/group_vars/homelab/vars.yml`.

Current ports:

| Port | Proto | Service |
|------|-------|---------|
| 22 | TCP | SSH |
| 9090 | TCP | Cockpit |
| 6443 | TCP | K3s API |
| 80 | TCP | HTTP ingress |
| 443 | TCP | HTTPS ingress |
| 445 | TCP | Samba |
| 51820 | UDP | WireGuard |

Only WireGuard UDP 51820 is intended for router forwarding. Do not forward Cockpit, K3s API,
Traefik ingress, or Samba directly to the internet.

## Backup Scripts

Backup helpers are local/manual scripts, not part of `site.yml`:

- `scripts/backup-secrets.sh` backs up selected `~/.homelab-secrets` files with `age -p`
- `scripts/backup-config.sh` backs up/restores `/srv/config`
- `scripts/backup-wireguard.sh` backs up/restores `/etc/wireguard/wg0.key` with `age -p`

Do not make these automatic unless explicitly asked.

## Variable Files

| File | Scope |
|------|-------|
| `inventory/group_vars/all.yml` | bootstrap/access vars and local key paths |
| `inventory/group_vars/homelab/vars.yml` | non-secret operational vars: ports, WireGuard, storage, K3s, Flux |
| `inventory/group_vars/homelab/secrets.sops.yml.example` | inactive documentation for a possible future inventory-SOPS path |

No `.env`, no `lookup('env', ...)`, and no inactive speculative variables.

## Useful Commands

```bash
./scripts/init-workstation.sh

ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u <admin> --ask-pass --ask-become-pass

ansible-playbook playbooks/site.yml
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml --check --diff
ansible-playbook playbooks/site.yml --tags <role>
ansible-playbook playbooks/verify.yml
ansible-playbook playbooks/verify.yml --tags <role>
ansible-lint playbooks/site.yml
ansible-playbook playbooks/site.yml --list-tags
```