# CLAUDE.md

Guidance for Claude Code in this repo. This is the single rules and architecture file for the
host Ansible project.

## Temporary Rules

> **TEMPORARY (remove when the `~/.homelab` restructure is finished):** WireGuard-role-related
> parts are off-limits. When updating anything, do **not** touch the `wireguard` role,
> `scripts/wireguard-client.sh`, `scripts/backup-wireguard.sh`, the `HL_WIREGUARD*` paths, or the
> WireGuard vars/comments in `inventory/group_vars/homelab/vars.yml`. Leave them exactly as-is.

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

- `## Now` — the one thing in flight, kept short; may carry an ordered `- [ ]` sub-checklist
- `## Next` — ordered shortlist (top = highest priority)
- `## Someday` — unordered ideas, parked notes, and undecided questions

Do not create status fields, per-task files, migration plans, TODO inventories, changelogs, or
additional planning documents. The `- [ ]` sub-checklist on a `Now` item is the *only*
decomposition surface. Current/future intent lives here; shipped history lives in git.

## Claude Code Operating Mode

Work in small, bounded passes. Before editing, read this file and `docs/planning/TASKS.md`.
`TASKS.md` is the only planning source. Work only the current `## Now` item (or its first
unchecked box) unless the human explicitly says otherwise. Never start anything from `## Next`
or `## Someday` on your own. Do not commit, clear `Now`, or start the next item unless asked.
Commit messages must not contain `Co-Authored-By`, Claude references, or any AI-attribution
trailer.

### The loop

Each phase answers one question and returns a named result. The question tells you which phase to
invoke; the result is what the next phase reads. Commands in `.claude/commands/` are thin entry
points into these phases — they do not restate this contract.

- **Assess** (`/assess`, read-only) — *"should we do this, and what would it entail?"* For a
  `Next`/`Someday` item that is a question, not a decision. Judges best-practice fitness first,
  then (if sound) rewrites the stub into a decided, scope-ready item — or settles it
  decided-against. Declares the item's classification (below). Changes no code.
  → `ASSESS: recommended | not recommended | needs input`.
- **Promote** (`/next`) — *"what am I working on?"* Move the top `Next` item verbatim into `Now`
  (keeping any structure Assess added). Refuse if `Now` is non-empty; don't auto-pull from
  `Someday`. → `PROMOTED: <item> | BLOCKED: Now holds <item> | EMPTY: Next`.
- **Scope** (`/scope`, read-only, Plan Mode) — *"how do I do this safely?"* Declares the task
  **classification** and the **verification plan**, lists in/out-of-scope, files, safe order.
  A plan without a verification section is invalid. Prefers **decompose** (below).
  → `SCOPE: proceed | decompose | split`.
- **Implement** (`/implement`) — *"make the smallest correct change."* One box only if `Now` has
  a checklist; then stop. → a diff summary.
- **Verify** (`/verify`) — *"does it work?"* Executes the verification the plan specified — it does
  not re-derive it. Unrunnable steps are `DEFERRED` with a reason, never silently skipped.
  → `VERIFIED | FAILED`.
- **Review** (`/review`) — *"did I stay in bounds and satisfy this task type?"* Walks the primary
  type's checklist plus scope-creep and invariant checks. → `OK to close | Needs changes`.
- **Close** (`/close`, only when asked) — *"bank it and advance the plan."* Refuse unless the
  latest `/verify` was `VERIFIED` **and no edits were made since it ran**. Commit message + the
  exact `TASKS.md` edit that clears `Now` or checks off the box.
  → `CLOSED: Now cleared | box N checked | BLOCKED`.

`/park` is available in any phase: append found-but-out-of-scope work as a one-line `Someday`
item and return to the current box — do not chase it.

### Task classification (two axes)

Scope (or Assess) declares both, once. Every later phase reads that declaration.

**Primary — the *nature* of the change. Sets the done-definition and the Review checklist:**

| Primary | Done when |
|---|---|
| **refactor** | behavior is unchanged — idempotent, `--check` parity before/after |
| **new feature** | the new capability works *and* is fully wired (toggle, `site.yml` + `verify.yml` in order, ports via `firewall`, verify task) |
| **bugfix** | the bug is gone *and* a check proves it won't regress |
| **architectural** | a changed contract/convention is updated *everywhere it is relied on*, including this file and any on-disk data migration |
| **docs** | the change is internally consistent with the code and rules |

A change is **architectural** when it alters a shared contract/convention — folder layout,
variable-naming rule, execution order, the prod/staging split — *not* by how many files it
touches. A wide change that adds capability without altering an existing contract is a **new
feature**.

**Secondary — the *components* touched. Each generates one verification recipe:**

| Component | Verified by |
|---|---|
| roles | `verify.yml` (+ role tags); `--check --diff` for behavior parity |
| inventory / group_vars | `--check --diff --limit <env>`; firewall/port correctness |
| scripts (`scripts/*.sh`) | `shellcheck` + a dry run of each touched script |
| this file / `TASKS.md` | consistency read against the code |
| on-disk layout (`~/.homelab`, `/srv`) | migration/restore check for existing data |

### Decomposition: box = unit of verification

**A box is verified by exactly one recipe.** If a task needs more than one recipe to be done, it
is more than one box — decompose it, one box per component/recipe. Decompose is the *default*
Scope outcome; "proceed as one change" is allowed only when the whole change is a single slice
verified one way. **Split** (the third outcome) is for when the item is really two *items* — kick
the extra part to `Next`/`Someday` and rewrite `Now`; do not absorb it silently.

A cross-surface task (e.g. a folder-structure change touching inventory + roles + scripts +
on-disk + this file) is therefore always decomposed — one box per surface, each with its own
recipe, each leaving the tree working. Example:

    ## Now
    - **<architectural item>.** <intent, unchanged.>
      - [ ] inventory: new path vars — `--check --diff --limit staging`
      - [ ] roles: read new paths — `verify.yml --limit staging`, idempotent re-run
      - [ ] scripts: updated to new layout — `shellcheck` + dry-run each
      - [ ] on-disk: migration path for existing data — restore-from-backup dry run
      - [ ] CLAUDE.md: Secrets Model / Variable Files updated — consistency read

### Verification vocabulary and safety

- Every `site.yml`/`verify.yml` run carries `--limit prod` or `--limit staging` — never a bare
  run (it hits both hosts; a staging-intended change could touch prod).
- Read-only `command` probes whose `rc` a later `when:` reads must set `check_mode: false`, or
  `--check` skips them and registers a fabricated `rc: 0`.
- A `run_once` task whose `when:` reads a per-host register evaluates the first host only — don't
  gate per-host logic behind `run_once`.
- A disabled toggleable role must run none of its own asserts, including under tag-scoped runs.
- For an **architectural** change, Review must always surface: did a documented invariant in this
  file change, and is this file updated to match? (Mandatory to check; the human decides.)

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

## Variable Naming

1. **Public role vars**: `<role>_<noun>` (`wireguard_peers`, `samba_shares`, `flux_repo_url`).
2. **Never the `ansible_` prefix** for custom vars — it is reserved for Ansible's own
   facts/connection/magic vars.
3. **Cross-role globals**: unprefixed only when genuinely global and defined in
   `inventory/group_vars/homelab/vars.yml` (`ssh_port`, `apt_cache_valid_time`). Do not add more casually.
4. **Booleans**: `<role>_enabled`; CLI safety gates may use `<action>_confirm`.
5. **Registered vars**: `<role>_<subject>_<kind>` where kind describes the result — `_stat`,
   `_check` (probe judged by rc), `_result`, `_slurp` — or a bare command mirror when it names
   the tool (`wireguard_show`, `flux_check`, `samba_testparm`).
6. **Facts (`set_fact`)**: role prefix + precise noun (`samba_force_user_name`).
7. **Files/dirs**: `_file` for file paths, `_dir`/`_dirs` for directories; no bare `_path`.
8. **Lists**: plural nouns (`_ports`, `_peers`, `_shares`, `_dirs`); structured item keys mirror
   the config format they template (`public_key`, `allowed_ips`).
9. **Service/package config vars** mirror the target config directive or module param name
   (`samba_create_mask`, `security_fail2ban_bantime`, `storage_owner`).
10. **Abbreviations**: only `dir`, `tmp`, `ns`, `uid`/`gid`, `url`, `port`; never `privkey`,
    `pubkey`, `ks`.

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
| `flux` | Flux deploy-key preflight, Flux bootstrap, SOPS age Secret injection | `flux_enabled`, requires `k3s_enabled` |

`site.yml` and `verify.yml` must gate toggleable roles with:

```yaml
when: <role>_enabled | default(true) | bool
```

`flux` requires `k3s_enabled: true`. `samba` requires `storage_enabled: true`.
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
8. `flux`

`playbooks/verify.yml` is read-only and should report `changed=0` on a healthy system.

## Access Model

A human admin user is created during Debian install. Before touching the server, run
`scripts/init-workstation.sh` on the workstation, once per host (target with `HL_HOST`, default
`atlas`; e.g. `HL_HOST=atlas-stg ./scripts/init-workstation.sh`). It creates that host's
`~/.homelab/local/<host>/` tree, generates its Ansible SSH key, Flux deploy key, and SOPS age key,
and writes that host's SSH alias into the shared `~/.homelab/local/ssh_config.partial`.

Two environments share this inventory: `atlas` (prod → `clusters/core`) and `atlas-stg`
(staging → `clusters/core-stg`). They differ only by `flux_path`; the nested `prod` /
`staging` groups under `homelab` carry that delta. Normal runs must target one environment with
`--limit` (`prod`/`staging`, or a host name) — a no-limit run hits both hosts. It is idempotent
(Flux bootstrap is namespace-gated) but a change intended for staging could then also touch prod.

First server run (per host):

```bash
ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml --limit atlas -u <admin> --ask-pass --ask-become-pass
```

Every later run (per environment):

```bash
ansible-playbook playbooks/site.yml --limit prod       # or: --limit staging
```

The `ansible` user must use key-only SSH and passwordless sudo. Keep the human admin as a break-glass
password login.

## Secrets Model

Local workstation secrets live under `~/.homelab/local/` (per host) and are never committed.
Layout is defined once as sourceable `HL_*` variables in `scripts/lib/paths.sh`.

Important paths (`<host>` = `atlas` / `atlas-stg`):

- `~/.homelab/local/<host>/bootstrap_user/id_ed25519`
- `~/.homelab/local/<host>/flux/deploy_key`
- `~/.homelab/local/ssh_config.partial`
- `~/.homelab/local/<host>/flux/sops-age.key`
- `~/.homelab-secrets/wireguard/` (WireGuard client keys — not migrated yet; see Temporary Rules)

The Flux deploy key is the only private-key carve-out: `flux` may stage it temporarily on
the server with `0600` permissions and `no_log: true`, run `flux bootstrap git`, then delete the temp
file in an `always` block. This carve-out does not apply to `authorized_keys`.

The SOPS age private key is injected into the cluster as `flux-system/sops-age` by `flux`.
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

Backup helpers are local/manual scripts, not part of `site.yml`. These still read the legacy
`~/.homelab-secrets`/`~/.homelab-backups` paths (kept in place for them); rewiring them onto
`scripts/lib/paths.sh` / the `~/.homelab` tree is a pending follow-up:

- `scripts/backup-secrets.sh` backs up selected `~/.homelab-secrets` files with `age -p`
- `scripts/backup-config.sh` backs up/restores `/srv/config`
- `scripts/backup-wireguard.sh` copies all WireGuard state (server `/etc/wireguard/wg0.key` plus the workstation `~/.homelab-secrets/wireguard/` client keys/configs) into a plaintext backup folder with a `RESTORE-NOTES.txt` for manual restore — temporary "get the data" solution, not encrypted

Do not make these automatic unless explicitly asked.

## Variable Files

| File | Scope |
|------|-------|
| `inventory/group_vars/all.yml` | bootstrap/access vars and local key paths |
| `inventory/group_vars/homelab/vars.yml` | shared connection + non-secret operational vars: ports, WireGuard, storage, K3s, Flux |
| `inventory/group_vars/prod.yml` | production environment delta (`atlas`): `flux_path: clusters/core` |
| `inventory/group_vars/staging.yml` | staging environment delta (`atlas-stg`): `flux_path: clusters/core-stg` |
| `inventory/host_vars/<host>.yml` | per-host overrides (e.g. a single host's `<role>_enabled: false`); none needed today |
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
