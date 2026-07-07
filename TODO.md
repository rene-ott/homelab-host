# TODO — workstation secrets/config reorganization

Not yet planned or implemented — discussion output only, captured for later.

## Why

`~/.homelab-secrets/` no longer describes its own contents accurately: it holds non-secret config
(`ssh/config`) alongside real secrets, and with multi-host support (per-role `<role>_enabled`
toggles, see `docs/planning/TASKS.md`) it needs a structure that's per-host where the content is
per-host, and fleet-wide only where it genuinely is.

## Proposed structure

```
~/.homelab/
├── local/
│   ├── config                       # SSH Host aliases for the whole fleet — one file, many Host blocks
│   └── atlas/
│       ├── bootstrap_user/
│       │   └── id_ed25519 (+.pub)    # this host's own Ansible login key — rotate independently per host
│       ├── flux_auth/
│       │   └── deploy_key (+.pub)
│       ├── flux_bootstrap/
│       │   └── sops-age.key
│       └── wireguard/
│           └── devices/
│               ├── workstation.key (+.pub/.conf)
│               └── phone.key (+.pub/.conf)
└── backups/
    ├── workstation/                  # snapshots of local/ — restores this machine if wiped
    └── atlas/                       # snapshots of atlas's own server-side state
        ├── config/
        └── wireguard/
```

## Key decisions made in discussion

- **`~/.homelab/{local,backups}`**, not `~/.homelab-secrets`/`~/.homelab-backups` — one neutral
  root, two siblings. Mirrors the project's existing `homelab-host`/`homelab-cluster` naming (a
  third "homelab" namespace for workstation-local state).
- **`local/` vs `backups/` is an origin split, not just live-vs-archive**: `backups/workstation/`
  snapshots material that already lives in `local/` (restores *this machine*); `backups/atlas/`
  snapshots data that normally lives on the server (`/srv/config`, `/etc/wireguard/wg0.key`) —
  pulled down and archived locally, restores *the server*.
- **Everything under `local/atlas/` is per-host**, named after the Ansible role that
  owns/consumes it (`bootstrap_user`, `flux_auth`, `flux_bootstrap`, `wireguard`) — a future
  second host gets its own parallel folder containing only the roles it actually enables (mirrors
  the `<role>_enabled` toggles directly: an empty/absent role folder means that host doesn't run
  it).
- **`bootstrap_user`'s key moves from a fleet-wide `ansible/` folder to per-host `atlas/bootstrap_user/`** —
  costs nothing extra now that `host_vars/<hostname>.yml` already exists for per-host overrides
  (just point `ansible_ssh_private_key_file` at the per-host path), and buys independent
  rotation/revocation per host if one is ever decommissioned or reinstalled.
- **`wireguard/devices/` holds every peer keypair uniformly**, workstation included — from the
  server's perspective the workstation is just another peer, no structurally special case.
- **`local/config` (the SSH alias file) stays a single fleet-wide file**, not per-host — it's not
  a secret and isn't independently rotated, and splitting it into per-host fragments would trade
  one file for N `Include` lines with no real benefit. Each `Host` block's `IdentityFile` just
  points at that host's own per-host key.

## Naming changes from today's `~/.homelab-secrets/`

| Today | Proposed |
|---|---|
| `ssh/ansible` (+`.pub`) | `local/atlas/bootstrap_user/id_ed25519` (+`.pub`) |
| `ssh/flux-deploy` (+`.pub`) | `local/atlas/flux_auth/deploy_key` (+`.pub`) |
| `age/homelab.agekey` | `local/atlas/flux_bootstrap/sops-age.key` |
| `ssh/config` | `local/config` |
| `wireguard/workstation.key` (+`.pub`/`.conf`) | `local/atlas/wireguard/devices/workstation.key` (+`.pub`/`.conf`) |
| `wireguard/phone.key` (+`.pub`/`.conf`) | `local/atlas/wireguard/devices/phone.key` (+`.pub`/`.conf`) |
| `~/.homelab-backups/secrets/` | `~/.homelab/backups/workstation/` |
| `~/.homelab-backups/config/` | `~/.homelab/backups/atlas/config/` |
| `~/.homelab-backups/wireguard/` | `~/.homelab/backups/atlas/wireguard/` |

## Open questions (not yet resolved)

- Is Flux material (`flux_auth`/`flux_bootstrap`) meant to be regenerated per host, or could a
  future second Flux-enabled host share the same deploy key / age key? Current lean: per-host
  isolation, regenerate as needed — but not confirmed.
- `bootstrap_user`'s key file was named `id_ed25519` to avoid the `ansible/ansible` stutter from
  an earlier draft — that's now moot since the folder is `bootstrap_user/`, so a more semantic
  name (e.g. `ansible_key`) is back on the table.

## Known blast radius (not yet scoped in detail)

Touches at minimum: `scripts/init-workstation.sh`, `scripts/backup-secrets.sh` (hardcoded
`SECRET_FILES`/`SRCS`/`DSTS` arrays), `scripts/backup-config.sh`, `scripts/backup-wireguard.sh`,
`scripts/wireguard-client.sh`, `scripts/clear-workstation.sh`, `roles/flux_auth/defaults`
(`flux_auth_bootstrap_ssh_key_file`), `roles/flux_bootstrap/defaults`
(`flux_bootstrap_sops_age_key_file`), `inventory/group_vars/all.yml` (`homelab_local_ssh_key_dir`),
`inventory/hosts.yml`/`host_vars/atlas.yml` (`ansible_ssh_private_key_file` becomes a per-host
override), and docs (`CLAUDE.md`, `docs/architecture.md`, `README.md`).

This is a separate concern from the per-role `<role>_enabled` toggle work (see
`docs/planning/TASKS.md` `## Now` / branch `feature/implement-multi-host-support`) — decide
separately whether it lands on the same branch or its own.
