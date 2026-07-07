# shellcheck shell=bash
#
# scripts/lib/paths.sh — sourceable path variables for the *target* ~/.homelab/ layout
# proposed in TODO.md (workstation secrets/config reorg). Nothing sources this file yet —
# scripts/*.sh still define their own ~/.homelab-secrets / ~/.homelab-backups paths inline.
# This exists so the new layout has one canonical definition ready for scripts to migrate
# onto later (see TODO.md "Known blast radius"), instead of each script re-deriving it.
#
# Target layout (see TODO.md for full rationale):
#
#   ~/.homelab/
#   ├── local/
#   │   ├── ssh_config.partial           # SSH Host aliases for the whole fleet
#   │   └── <HOMELAB_HOST>/              # e.g. atlas
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
#           └── <HOMELAB_HOST>/           # snapshots of that host's server-side state
#               ├── config/
#               └── wireguard/
#
# HOMELAB_HOST selects the per-host subtree; set it before sourcing to override the default:
#   HOMELAB_HOST=nas source scripts/lib/paths.sh
HOMELAB_HOST="${HOMELAB_HOST:-atlas}"

HOMELAB_ROOT="${HOME}/.homelab"
HOMELAB_LOCAL_DIR="${HOMELAB_ROOT}/local"
HOMELAB_BACKUPS_DIR="${HOMELAB_ROOT}/backups"

# Fleet-wide, not per-host — see TODO.md's rationale for why the SSH alias stays a single file.
HOMELAB_SSH_CONFIG="${HOMELAB_LOCAL_DIR}/ssh_config.partial"

HOMELAB_HOST_LOCAL_DIR="${HOMELAB_LOCAL_DIR}/${HOMELAB_HOST}"

HOMELAB_BOOTSTRAP_USER_DIR="${HOMELAB_HOST_LOCAL_DIR}/bootstrap_user"
HOMELAB_BOOTSTRAP_USER_KEY="${HOMELAB_BOOTSTRAP_USER_DIR}/id_ed25519"

HOMELAB_FLUX_AUTH_DIR="${HOMELAB_HOST_LOCAL_DIR}/flux_auth"
HOMELAB_FLUX_AUTH_KEY="${HOMELAB_FLUX_AUTH_DIR}/deploy_key"

HOMELAB_FLUX_BOOTSTRAP_DIR="${HOMELAB_HOST_LOCAL_DIR}/flux_bootstrap"
HOMELAB_FLUX_BOOTSTRAP_AGE_KEY="${HOMELAB_FLUX_BOOTSTRAP_DIR}/sops-age.key"

HOMELAB_WIREGUARD_DIR="${HOMELAB_HOST_LOCAL_DIR}/wireguard"
HOMELAB_WIREGUARD_DEVICES_DIR="${HOMELAB_WIREGUARD_DIR}/devices"

HOMELAB_BACKUPS_LOCAL_DIR="${HOMELAB_BACKUPS_DIR}/local"

HOMELAB_BACKUPS_SERVER_DIR="${HOMELAB_BACKUPS_DIR}/server"
HOMELAB_HOST_BACKUPS_DIR="${HOMELAB_BACKUPS_SERVER_DIR}/${HOMELAB_HOST}"
HOMELAB_HOST_CONFIG_BACKUP_DIR="${HOMELAB_HOST_BACKUPS_DIR}/config"
HOMELAB_HOST_WIREGUARD_BACKUP_DIR="${HOMELAB_HOST_BACKUPS_DIR}/wireguard"
