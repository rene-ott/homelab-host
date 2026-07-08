#!/usr/bin/env bash
# Copies ALL WireGuard state needed to rebuild the VPN into a plain (unencrypted) backup folder:
#   - server private key:  atlas:/etc/wireguard/wg0.key
#   - workstation clients:  ~/.homelab-secrets/wireguard/ (*.key, *.pub, *.conf)
# TEMPORARY "get the data" solution: files are copied in the clear (no age, no tar) and a
# RESTORE-NOTES.txt is written explaining how to apply each piece back MANUALLY. The peer list,
# listen port, and overlay subnet already live in inventory/group_vars/homelab/vars.yml (git).
# Not part of Ansible site.yml — run manually, disaster-recovery only.
#
# WARNING: the backup folder holds plaintext private keys. Keep it off shared storage and delete
# it once the data is safely stored elsewhere.
set -euo pipefail

REMOTE_HOST="atlas"
REMOTE_KEY_PATH="/etc/wireguard/wg0.key"
CLIENT_DIR="${HOME}/.homelab-secrets/wireguard"
BACKUP_ROOT="${HOME}/.homelab-backups/wireguard"

require_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: required command not found: $cmd" >&2; exit 1; }
  done
}

short() { echo "${1/#$HOME/\~}"; }

require_cmd ssh

timestamp="$(date +%Y%m%d-%H%M%S)"
dest="${BACKUP_ROOT}/${timestamp}"
mkdir -p "${dest}/server" "${dest}/workstation"
chmod 700 "${BACKUP_ROOT}" "${dest}" "${dest}/server" "${dest}/workstation"

# ── server private key ─────────────────────────────────────────────────────────
echo "Fetching server private key from ${REMOTE_HOST}:${REMOTE_KEY_PATH}..."
ssh "${REMOTE_HOST}" "sudo -n cat ${REMOTE_KEY_PATH}" > "${dest}/server/wg0.key"
chmod 600 "${dest}/server/wg0.key"

# ── workstation client secrets ─────────────────────────────────────────────────
client_count=0
if [[ -d "${CLIENT_DIR}" ]] && compgen -G "${CLIENT_DIR}/*" >/dev/null; then
  cp -a "${CLIENT_DIR}/." "${dest}/workstation/"
  # Normalise permissions on the copies (cp -a carried the source dir's mode over).
  chmod 700 "${dest}/workstation"
  find "${dest}/workstation" -type f \( -name '*.key' -o -name '*.conf' \) -exec chmod 600 {} +
  find "${dest}/workstation" -type f -name '*.pub' -exec chmod 644 {} +
  client_count="$(find "${dest}/workstation" -type f | wc -l | tr -d ' ')"
else
  echo "WARNING: no workstation client secrets found in $(short "${CLIENT_DIR}") — skipping." >&2
fi

# ── restore notes ──────────────────────────────────────────────────────────────
cat > "${dest}/RESTORE-NOTES.txt" <<EOF
WireGuard backup taken ${timestamp}
Plain (unencrypted) copies — temporary, apply manually.

Contents
  server/wg0.key       server private key from ${REMOTE_HOST}:${REMOTE_KEY_PATH}
  workstation/*        client keys/configs from ~/.homelab-secrets/wireguard/
                       (${client_count} file(s); empty if none existed)

1) Restore the SERVER private key
   ssh ${REMOTE_HOST} "sudo install -o root -g root -m 600 /dev/stdin ${REMOTE_KEY_PATH}" < server/wg0.key
   ansible-playbook playbooks/site.yml --tags wireguard
   (re-renders wg0.conf from the restored key and restarts the interface)

2) Restore the WORKSTATION client secrets
   mkdir -p ~/.homelab-secrets/wireguard && chmod 700 ~/.homelab-secrets/wireguard
   cp workstation/* ~/.homelab-secrets/wireguard/
   chmod 600 ~/.homelab-secrets/wireguard/*.key ~/.homelab-secrets/wireguard/*.conf
   chmod 644 ~/.homelab-secrets/wireguard/*.pub
   # The *.conf files hold the server endpoint (host:port) — kept out of git, only stored here.

3) Peer list / port / subnet
   Already in inventory/group_vars/homelab/vars.yml (git) — nothing to restore.
EOF
chmod 600 "${dest}/RESTORE-NOTES.txt"

# ── summary ────────────────────────────────────────────────────────────────────
printf '\nBacked up to %s:\n' "$(short "${dest}")"
printf '  server/wg0.key\n'
if [[ "${client_count}" -gt 0 ]]; then
  find "${dest}/workstation" -type f -printf '  workstation/%P\n' | sort
else
  printf '  workstation/ (empty — no client secrets found)\n'
fi
printf '  RESTORE-NOTES.txt\n'
printf '\nThese are PLAINTEXT secrets — store them safely and delete %s when done.\n' "$(short "${dest}")"
