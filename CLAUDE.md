# CLAUDE.md

Guidance for Claude Code in this repo — the single rules file for the host Ansible project,
in two sections: **repo map** and **Ansible rules**.

## Repo Purpose

`homelab-host` is the Ansible project for the single-node Debian
server and its K3s platform. It configures the OS layer (security, firewall, cockpit), installs
K3s, and bootstraps Flux CD once — pointing Flux at the companion
**[`homelab-cluster`](https://github.com/rene-ott/homelab-cluster)** GitOps repo. After bootstrap,
all K8s app changes go into `homelab-cluster`; this repo only manages the host.

Ansible code (`inventory/`, `roles/`, `playbooks/`, `ansible.cfg`) lives at the **repo root**.
The Flux GitOps tree (apps, infrastructure, SOPS secrets) lives in the separate
**`rene-ott/homelab-cluster`** repository — Flux watches that repo and deploys workloads
automatically. Ansible never touches K8s apps.

### Working Directories & shared docs

- **Run Claude Code and Ansible from the repo root** — `ansible.cfg` is at the root.
- **Project docs and planning live under `docs/`** (at the repo root):
  `docs/architecture.md` (design + ports), `docs/planning/TASKS.md` (the living Now/Next/Someday plan),
  and `docs/planning/LOG.md` (one line per shipped change).

## Git Commits

Commits in this repo must not carry a `Co-Authored-By: Claude` trailer or any other AI-attribution
line — this overrides Claude Code's default commit-message behavior. Commit messages should read as
if written solely by the human author.

---

# Ansible Rules

## Project Purpose

This repo configures the single-node Debian server and installs the K3s platform. Ansible code
(`inventory/`, `roles/`, `playbooks/`, `ansible.cfg`) lives at the repo root — run all Ansible
commands from here. See `docs/architecture.md` for the full picture.

## Key Rules

1. **One role per concern.** Do not merge multiple services into one role.
2. **Firewall ports in group_vars only.** All host-level ports live in `inventory/group_vars/homelab/vars.yml`. No role other than `firewall` may open ports.
3. **K3s platform ≠ K3s apps.** The `k3s` role installs K3s only. `flux_auth` and `flux_bootstrap` handle Flux CD bootstrap. K3s apps are managed by Flux CD from the `homelab-cluster` repo — not by Ansible.
4. **K3s apps use ingress.** Apps are exposed on 80/443 via Traefik. Do not open app-specific host ports.
5. **No plain-text secrets in repo.** Ansible reads the SOPS Age private key at the host's per-host path under `~/.homelab/local/<hostname>/flux_bootstrap/sops-age.key` on the workstation (see `scripts/lib/paths.sh`, resolved via `inventory/host_vars/<hostname>.yml`'s `flux_bootstrap_sops_age_key_file`) and injects it into `flux-system/sops-age` via the `flux_bootstrap` role (`no_log: true`). This is unconditional — Ansible fails fast with a remediation message if the key is absent. All Kubernetes runtime secrets (e.g. `CLOUDFLARE_API_TOKEN`) live as SOPS-encrypted manifests in the `homelab-cluster` repo and are decrypted in-cluster by Flux. Non-secret config (server host, Flux URL/path, key paths) lives directly in inventory files and role defaults — no `.env`, no `scripts/setup.sh`, no `lookup('env', ...)`.
6. **Config only for implemented roles.** `inventory/group_vars` and role defaults hold only variables an implemented role actually uses — no speculative config for work not yet done. Unbuilt ideas (and their planned variables) live in `docs/planning/TASKS.md` until built.
7. **Bootstrap access uses a dedicated playbook.** You create a human admin (password + sudo) during the Debian install. Run `scripts/init-workstation.sh` first (generates all three keys, writes SSH alias), then `playbooks/bootstrap-user.yml` (with `inventory/bootstrap.yml` and `--ask-pass --ask-become-pass`) provisions the **`ansible`** user on the server. Every run after uses `playbooks/site.yml` connecting as `ansible` by key. The `flux_auth` role verifies the Flux deploy key can reach GitHub.
8. **The `ansible` automation user is provisioned by `bootstrap_user`.** It creates the user (sudo group, `/bin/bash`) and authorizes the workstation-generated public key. It must never be given a usable password or deleted.
9. **Private SSH keys must stay on the workstation.** Deploy only public keys, via `ansible.posix.authorized_key` — never raw `copy` for `authorized_keys`. (`scripts/init-workstation.sh` generates the `ansible` keypair on the workstation; only its public half reaches the server.) **Carve-out — the Flux deploy key:** the `flux_bootstrap` role is the one exception, since a deploy key's private half *must* reach the server (it lives in the in-cluster `flux-system` Secret for Flux to pull). The role stages it into a `0600` temp file (`copy` + `no_log: true`) for the bootstrap only, then deletes it in an `always` block. Applies *only* to the Flux deploy key — `authorized_keys` still follows the rule above.
10. **Passwordless sudo for the `ansible` user is configured by `bootstrap_user`.** Via `/etc/sudoers.d/ansible` with `ansible ALL=(ALL) NOPASSWD:ALL` (owner root, group root, mode 0440, validated with `visudo -cf %s`). The bootstrap run needs `--ask-pass --ask-become-pass`; once `ansible` exists with NOPASSWD sudo and its key, all later runs need neither.
11. **Every role except `security`/`firewall` is individually toggleable per host.** Each has a `<role>_enabled` boolean in its own `defaults/main.yml`, defaulting to `true` — set `<role>_enabled: false` in a host's `inventory/host_vars/<hostname>.yml` to skip that role entirely on that host. `playbooks/site.yml`/`verify.yml` gate each role with `when: <role>_enabled | default(true) | bool`; because that `when:` applies to *every* task the role contributes (Ansible's documented behavior for the `roles:` keyword and static `import_role`), it also skips a disabled role's own fail-fast asserts (e.g. `flux_auth`'s/`flux_bootstrap`'s workstation-key checks from rule #5) — the assert and the functional tasks are never split. `security`/`firewall` have no toggle and always run; there's no scenario where a homelab host should skip OS hardening or the firewall. `bootstrap_user` isn't part of this scheme either — it only runs via the separate `bootstrap-user.yml` flow (rule #7), not `site.yml`. `flux_auth`/`flux_bootstrap` require `k3s_enabled: true`, and `samba` requires `storage_enabled: true` — both `site.yml`'s `pre_tasks` and each role's own guard task fail fast on an inconsistent combination. This is architecturally distinct from the removed `flux_bootstrap_enable_sops` flag (rule #5's "unconditional" fail-fast is about a flag that gated one sub-task *inside* an always-running role while its assert stayed live — the opposite of gating the whole role from outside).

## Role Map

| Role | Concern | Toggle |
|------|---------|--------|
| bootstrap_user | (bootstrap only) creates `ansible` OS user, installs public key, grants passwordless sudo | always on, not part of `site.yml` |
| security | SSH hardening, fail2ban, auto-upgrades | always on |
| firewall | ufw rules (reads `inventory/group_vars/homelab/vars.yml`) | always on |
| wireguard | Split-tunnel WireGuard VPN — UDP 51820, overlay 10.10.10.0/24, peers in `vars.yml` | `wireguard_enabled` |
| cockpit | Web management UI on port 9090 | `cockpit_enabled` |
| storage | Shared, app-agnostic host directory roots for K3s apps (media/config/cache) | `storage_enabled` |
| samba | Guest, read-write SMB share exposing `/srv/media` over the network (port 445) | `samba_enabled` (requires `storage_enabled`) |
| k3s | K3s platform installation and configuration (wait for node Ready) | `k3s_enabled` |
| flux_auth | Flux CD deploy-key lifecycle: verify key exists, display pubkey for GitHub registration, gate before bootstrap | `flux_auth_enabled` (requires `k3s_enabled`) |
| flux_bootstrap | Flux CD bootstrap: install flux CLI, run flux bootstrap git, optionally seed sops-age Secret | `flux_bootstrap_enabled` (requires `k3s_enabled`) |

## Variable Files

| File | Scope |
|------|-------|
| `inventory/group_vars/all.yml` | Fleet-wide bootstrap/access vars (`ansible_admin_user`, `ansible_admin_sudo_group`) |
| `inventory/group_vars/homelab/vars.yml` | Non-secret operational vars: SSH port, apt cache, firewall ports, WireGuard listen port/overlay address/peers, storage directory roots, K3s/Flux versions + bootstrap coordinates |
| `inventory/group_vars/homelab/secrets.sops.yml.example` | Documentation only — describes the future optional encrypted-secrets path |
| `inventory/host_vars/<hostname>.yml` | Per-host overrides: `<role>_enabled` toggles (rule #11) and the per-host secret key paths (`ansible_admin_key_path`, `flux_auth_bootstrap_ssh_key_file`, `flux_bootstrap_sops_age_key_file`) under `~/.homelab/local/<hostname>/...` |

## Workstation One-Time Setup

After a fresh clone, install tooling once:

```bash
# Install all workstation dependencies (idempotent, re-runnable)
./scripts/install-deps.sh   # tooling only — no secrets, no SSH keys
```

All three keys (ansible SSH, flux-deploy SSH, SOPS age) are generated by `scripts/init-workstation.sh`,
which sources `scripts/lib/paths.sh` (the source of truth for this layout — see `TODO.md` for the
full rationale) — no manual `age-keygen` or `ssh-keygen` needed:

```text
~/.homelab/
├── local/
│   ├── ssh_config.partial            # SSH Host aliases for the whole fleet — one block per host
│   └── atlas/                        # per-host, named after the prompted host alias
│       ├── bootstrap_user/
│       │   └── id_ed25519 (+.pub)    # private key for Ansible SSH login to the VPS
│       ├── flux_auth/
│       │   └── deploy_key (+.pub)    # private key for Flux GitHub deploy-key bootstrap
│       └── flux_bootstrap/
│           └── sops-age.key          # SOPS age keypair — private key stays local, never committed
└── backups/
    ├── local/                        # snapshots of local/ (scripts/backup-secrets.sh — not yet migrated)
    └── server/
        └── atlas/                    # snapshots of atlas's server-side state (not yet migrated)
```

`~/.ssh/config` gets one `Include ~/.homelab/local/ssh_config.partial` line so `ssh atlas` works.
The SSH alias no longer sets `User ansible` — Ansible reads `ansible_user`/
`ansible_ssh_private_key_file` from inventory (`inventory/host_vars/<hostname>.yml`), never from
this file.

> **Partially migrated:** `scripts/init-workstation.sh` and the inventory are wired onto this
> layout. `scripts/backup-secrets.sh`, `backup-config.sh`, `backup-wireguard.sh`,
> `wireguard-client.sh`, and `clear-workstation.sh` are not yet — they still read/write
> `~/.homelab-secrets/`/`~/.homelab-backups/` (see `docs/planning/TASKS.md`'s Someday item).

`init-workstation.sh` prompts for a host alias, the server IP or DNS name, and whether to generate each missing key.

After running it, follow the printed **homelab-cluster next steps** to add the age public key to
`.sops.yaml`, encrypt secrets, and push `homelab-cluster`:

```bash
# Encrypt a secret in the homelab-cluster checkout:
SOPS_AGE_KEY_FILE=~/.homelab/local/atlas/flux_bootstrap/sops-age.key \
  sops -e -i infrastructure/configs/cert-manager/overlays/homelab/cloudflare-api-token.sops.yaml
# Commit only the encrypted output — never commit a plaintext token
```

## Useful Commands

All commands run from the **repo root**. `ansible.cfg` sets `inventory = inventory/hosts.yml` — no flags needed for normal runs.

```bash
# First run — init workstation, then bootstrap the ansible user
./scripts/init-workstation.sh
ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u <admin> --ask-pass --ask-become-pass

# Everything after — runs as ansible by key, no flags
ansible-playbook playbooks/site.yml

# Useful narrowing / checks
ansible-playbook playbooks/site.yml --tags <role>   # single role
ansible-playbook playbooks/site.yml --check --diff  # post-bootstrap dry run
ansible-playbook playbooks/verify.yml               # read-only health check
ansible-playbook playbooks/verify.yml --tags <role> # single role
ansible-lint playbooks/site.yml                     # lint
ansible-playbook playbooks/site.yml --list-tags     # list accepted role tags
```

## Task Workflow

Planning lives in two flat files under `docs/planning/` — no per-task files, no status lifecycle:

- **`docs/planning/TASKS.md`** — the living plan: `## Now` (the one thing in flight, ≤5 lines with a few
  checkboxes), `## Next` (ordered shortlist), `## Someday` (unordered ideas + their impl notes).
- **`docs/planning/LOG.md`** — append-only, newest first, one line per shipped change.

The loop: pick from **Next** → write it into **Now** (goal + checkboxes) → build → verify (for Ansible,
`--syntax-check` then `--tags <role>` on the server; for apps, commit to `homelab-cluster` and let Flux reconcile) →
commit (the message is the detailed record) → add one line to **LOG.md** → clear **Now**.

## Access Model

- A human **admin** (password + sudo) is created during the Debian install.
- `scripts/init-workstation.sh` (run once) generates keys and writes the SSH alias on the workstation.
- `playbooks/bootstrap-user.yml` (run once, with `inventory/bootstrap.yml`) connects as the admin over password and provisions the **`ansible`** user via `bootstrap_user`: workstation-generated keypair (public half on the server) and passwordless sudo via `/etc/sudoers.d/ansible`.
- Every run after uses `playbooks/site.yml`, connecting as `ansible` by key — no `--ask-pass`/`--ask-become-pass`.
- SSH hardening (disabling password login, `sshd_config`) belongs to the `security` role. Run `security` only **after** `ansible` key login is confirmed — otherwise you close the admin's password channel before the key works.
