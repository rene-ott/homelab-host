# shellcheck shell=bash
#
# Sourceable path variables for the ~/.homelab layout (see TODO.md for full rationale).
# scripts/init-workstation.sh sources this file; scripts/backup-secrets.sh, backup-config.sh,
# backup-wireguard.sh, wireguard-client.sh, and clear-workstation.sh still define their own
# ~/.homelab-secrets / ~/.homelab-backups paths inline (see docs/planning/TASKS.md's "Finish
# wiring scripts/lib/paths.sh into the remaining scripts" for the remaining migration).
#
# Target layout:
#
#   ~/.homelab/
#   ├── local/
#   │   ├── ssh_config.partial           # SSH Host aliases for the whole fleet
#   │   └── <HL_HOST>/                   # e.g. atlas
#   │       ├── bootstrap_user/
#   │       │   └── id_ed25519 (+.pub)
#   │       ├── flux_auth/
#   │       │   └── deploy_key (+.pub)
#   │       ├── flux_bootstrap/
#   │       │   └── sops-age.key
#   │       └── wireguard/
#   │           └── devices/
#   │               ├── workstation.key (+.pub/.conf)
#   │               └── phone.key (+.pub/.conf)
#   └── backups/
#       ├── local/                        # snapshots of local/ — restores this machine
#       └── server/
#           └── <HL_HOST>/                # snapshots of that host's server-side state
#               ├── config/
#               └── wireguard/
#
# Override before sourcing:
#
#   HL_HOST=nas source scripts/lib/paths.sh

HL_HOST="${HL_HOST:-atlas}"

HL_ROOT="${HOME}/.homelab"
HL_LOCAL="${HL_ROOT}/local"
HL_BACKUPS="${HL_ROOT}/backups"

HL_SSH_CONFIG="${HL_LOCAL}/ssh_config.partial"
HL_GLOBAL_SSH_CONFIG="${HOME}/.ssh/config"

HL_HOST_LOCAL="${HL_LOCAL}/${HL_HOST}"

HL_BOOTSTRAP_USER="${HL_HOST_LOCAL}/bootstrap_user"
HL_BOOTSTRAP_USER_KEY="${HL_BOOTSTRAP_USER}/id_ed25519"

HL_FLUX_AUTH="${HL_HOST_LOCAL}/flux_auth"
HL_FLUX_AUTH_KEY="${HL_FLUX_AUTH}/deploy_key"

HL_FLUX_BOOTSTRAP="${HL_HOST_LOCAL}/flux_bootstrap"
HL_FLUX_BOOTSTRAP_AGE_KEY="${HL_FLUX_BOOTSTRAP}/sops-age.key"

HL_WIREGUARD="${HL_HOST_LOCAL}/wireguard"
HL_WIREGUARD_DEVICES="${HL_WIREGUARD}/devices"

HL_BACKUPS_LOCAL="${HL_BACKUPS}/local"
HL_BACKUPS_SERVER="${HL_BACKUPS}/server"

HL_HOST_BACKUPS="${HL_BACKUPS_SERVER}/${HL_HOST}"
HL_HOST_CONFIG_BACKUP="${HL_HOST_BACKUPS}/config"
HL_HOST_WIREGUARD_BACKUP="${HL_HOST_BACKUPS}/wireguard"
