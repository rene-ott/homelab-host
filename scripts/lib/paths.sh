# shellcheck shell=bash
#
# Sourceable path variables for the ~/.homelab layout. scripts/init-workstation.sh sources this
# file. The backup helpers (backup-secrets.sh, backup-config.sh, backup-wireguard.sh) and
# wireguard-client.sh still define their own ~/.homelab-secrets / ~/.homelab-backups paths inline;
# wiring them onto these variables is a later pass (see docs/planning/TASKS.md). The HL_WIREGUARD*
# variables below are defined but not yet consumed.
#
# Target layout:
#
#   ~/.homelab/
#   ├── local/
#   │   ├── ssh_config.partial           # SSH Host aliases for the whole fleet
#   │   └── <HL_HOST>/                   # e.g. atlas
#   │       ├── bootstrap_user/
#   │       │   └── id_ed25519 (+.pub)
#   │       ├── flux/
#   │       │   ├── deploy_key (+.pub)
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

HL_FLUX="${HL_HOST_LOCAL}/flux"
HL_FLUX_DEPLOY_KEY="${HL_FLUX}/deploy_key"
HL_FLUX_AGE_KEY="${HL_FLUX}/sops-age.key"

HL_WIREGUARD="${HL_HOST_LOCAL}/wireguard"
HL_WIREGUARD_DEVICES="${HL_WIREGUARD}/devices"

HL_BACKUPS_LOCAL="${HL_BACKUPS}/local"
HL_BACKUPS_SERVER="${HL_BACKUPS}/server"

HL_HOST_BACKUPS="${HL_BACKUPS_SERVER}/${HL_HOST}"
HL_HOST_CONFIG_BACKUP="${HL_HOST_BACKUPS}/config"
HL_HOST_WIREGUARD_BACKUP="${HL_HOST_BACKUPS}/wireguard"
