# TODO — workstation secrets/config reorganization

Not yet planned or implemented — discussion output only, captured for later. This doc is the
rationale; `scripts/lib/paths.sh` is the canonical, executable source of truth for the target
`~/.homelab/` layout — if the two ever disagree, `paths.sh` wins and this doc is stale.

## Why

`~/.homelab-secrets/` no longer describes its own contents accurately: it holds non-secret config
(`ssh/config`) alongside real secrets, and with multi-host support (per-role `<role>_enabled`
toggles, see `docs/planning/TASKS.md`) it needs a structure that's per-host where the content is
per-host, and fleet-wide only where it genuinely is.

## Proposed structure

```
~/.homelab/
├── local/
│   ├── ssh_config.partial            # SSH Host aliases for the whole fleet — Include'd into ~/.ssh/config
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
    ├── local/                        # snapshots of local/ — restores this machine if wiped
    └── server/
        └── atlas/                    # snapshots of atlas's own server-side state
            ├── config/
            └── wireguard/
```

## Key decisions made in discussion

- **`~/.homelab/{local,backups}`**, not `~/.homelab-secrets`/`~/.homelab-backups` — one neutral
  root, two siblings. Mirrors the project's existing `homelab-host`/`homelab-cluster` naming (a
  third "homelab" namespace for workstation-local state).
- **`local/` vs `backups/` is an origin split, not just live-vs-archive**: `backups/local/`
  snapshots material that already lives in `local/` (restores *this machine*); `backups/server/atlas/`
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
- **`local/ssh_config.partial` (the SSH alias file) stays a single fleet-wide file**, not per-host — it's not
  a secret and isn't independently rotated, and splitting it into per-host fragments would trade
  one file for N `Include` lines with no real benefit. Each `Host` block's `IdentityFile` just
  points at that host's own per-host key.

## Naming changes from today's `~/.homelab-secrets/`

| Today | Proposed |
|---|---|
| `ssh/ansible` (+`.pub`) | `local/atlas/bootstrap_user/id_ed25519` (+`.pub`) |
| `ssh/flux-deploy` (+`.pub`) | `local/atlas/flux_auth/deploy_key` (+`.pub`) |
| `age/homelab.agekey` | `local/atlas/flux_bootstrap/sops-age.key` |
| `ssh/config` | `local/ssh_config.partial` |
| `wireguard/workstation.key` (+`.pub`/`.conf`) | `local/atlas/wireguard/devices/workstation.key` (+`.pub`/`.conf`) |
| `wireguard/phone.key` (+`.pub`/`.conf`) | `local/atlas/wireguard/devices/phone.key` (+`.pub`/`.conf`) |
| `~/.homelab-backups/secrets/` | `~/.homelab/backups/local/` |
| `~/.homelab-backups/config/` | `~/.homelab/backups/server/atlas/config/` |
| `~/.homelab-backups/wireguard/` | `~/.homelab/backups/server/atlas/wireguard/` |

## Decisions confirmed by scripts/lib/paths.sh

Both were open questions in earlier discussion; `scripts/lib/paths.sh` has since committed to an
answer for each, so they're settled unless someone deliberately revisits them:

- **Flux material (`flux_auth`/`flux_bootstrap`) is per-host, not shared** — `paths.sh` nests
  `HOMELAB_FLUX_AUTH_DIR`/`HOMELAB_FLUX_BOOTSTRAP_DIR` under `HOMELAB_HOST_LOCAL_DIR` (i.e. under
  `atlas/`), confirming the "per-host isolation, regenerate as needed" lean.
- **`bootstrap_user`'s key file stays named `id_ed25519`** — `paths.sh` defines
  `HOMELAB_BOOTSTRAP_USER_KEY` as `bootstrap_user/id_ed25519`; the `ansible_key` alternative was
  considered and dropped.

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
