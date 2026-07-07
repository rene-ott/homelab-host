#!/usr/bin/env bash
# Backs up / restores the WireGuard server's private key (/etc/wireguard/wg0.key).
# This is the only WireGuard state that isn't already in git — the peer list, listen
# port, and overlay subnet all live in inventory/group_vars/homelab/vars.yml. Restoring
# this key onto a freshly rebuilt server preserves the server's identity (public key),
# so existing client configs keep working without any changes.
# Not part of Ansible site.yml — run manually, disaster-recovery only.
set -euo pipefail

REMOTE_HOST="atlas"
REMOTE_KEY_PATH="/etc/wireguard/wg0.key"
BACKUP_DIR="${HOME}/.homelab-backups/wireguard"

require_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: required command not found: $cmd" >&2; exit 1; }
  done
}

short() { echo "${1/#$HOME/\~}"; }

require_cmd ssh age

mkdir -p "${BACKUP_DIR}"

# ── top-level menu ────────────────────────────────────────────────────────────
printf '\nWireGuard server key — what do you want to do?\n'
printf '  1) Backup\n'
printf '  2) Restore\n'
read -rp 'Choice [1/2]: ' _choice
case "${_choice}" in
  1) action="backup" ;;
  2) action="restore" ;;
  *) echo "Invalid choice." >&2; exit 1 ;;
esac

# ── backup ────────────────────────────────────────────────────────────────────
if [[ "${action}" == "backup" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_path="${BACKUP_DIR}/wg0-${timestamp}.key.age"
  tmp_plain="$(mktemp)"
  trap 'rm -f "${tmp_plain}"' EXIT

  echo "Fetching server private key from ${REMOTE_HOST}:${REMOTE_KEY_PATH}..."
  ssh "${REMOTE_HOST}" "sudo -n cat ${REMOTE_KEY_PATH}" > "${tmp_plain}"

  age -p -o "${backup_path}" "${tmp_plain}"
  chmod 600 "${backup_path}"

  echo "Backed up: $(short "${backup_path}")"
  echo "Keep the passphrase safe — it's required to restore."
fi

# ── restore ───────────────────────────────────────────────────────────────────
if [[ "${action}" == "restore" ]]; then
  mapfile -t backups < <(compgen -G "${BACKUP_DIR}/wg0-*.key.age" 2>/dev/null | sort -r || true)

  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "ERROR: no backups found in $(short "${BACKUP_DIR}")" >&2
    exit 1
  fi

  printf '\nAvailable backups:\n'
  for i in "${!backups[@]}"; do
    printf '  %d) %s\n' "$((i+1))" "$(short "${backups[$i]}")"
  done
  read -rp "Choice [1-${#backups[@]}] (default: 1 = most recent): " _restore_choice
  _restore_choice="${_restore_choice:-1}"
  _restore_idx=$(( _restore_choice - 1 ))
  [[ "${_restore_idx}" -ge 0 && "${_restore_idx}" -lt "${#backups[@]}" ]] || { echo "Invalid choice." >&2; exit 1; }
  restore_path="${backups[${_restore_idx}]}"

  tmp_plain="$(mktemp)"
  trap 'rm -f "${tmp_plain}"' EXIT
  age -d -o "${tmp_plain}" "${restore_path}"

  printf '\nThis will overwrite %s:%s with %s\n' "${REMOTE_HOST}" "${REMOTE_KEY_PATH}" "$(short "${restore_path}")"
  read -rp 'Continue? [y/N] ' _ans
  [[ "${_ans}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

  ssh "${REMOTE_HOST}" "sudo -n install -o root -g root -m 600 /dev/stdin ${REMOTE_KEY_PATH}" < "${tmp_plain}"

  echo "Restored $(short "${restore_path}") -> ${REMOTE_HOST}:${REMOTE_KEY_PATH}"
  echo "Now run: ansible-playbook playbooks/site.yml --tags wireguard"
fi
