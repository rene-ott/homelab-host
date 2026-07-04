#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="atlas"
REMOTE_DIR="/srv/config"
BACKUP_DIR="${HOME}/.homelab-backups/config"

require_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: required command not found: $cmd" >&2; exit 1; }
  done
}

short() { echo "${1/#$HOME/\~}"; }

require_cmd ssh tar

mkdir -p "${BACKUP_DIR}"

# ── top-level menu ────────────────────────────────────────────────────────────
printf '\nHomelab config — what do you want to do?\n'
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
  backup_path="${BACKUP_DIR}/config-${timestamp}.tar.gz"
  tmp_path="${backup_path}.tmp"
  trap 'rm -f "${tmp_path}"' EXIT

  echo "Backing up ${REMOTE_HOST}:${REMOTE_DIR} -> $(short "${backup_path}")"

  ssh "${REMOTE_HOST}" "sudo -n tar czf - -C /srv config" > "${tmp_path}"
  mv "${tmp_path}" "${backup_path}"

  size="$(du -h "${backup_path}" | cut -f1)"
  echo "Done: $(short "${backup_path}") (${size})"
fi

# ── restore ───────────────────────────────────────────────────────────────────
if [[ "${action}" == "restore" ]]; then
  mapfile -t backups < <(compgen -G "${BACKUP_DIR}/config-*.tar.gz" 2>/dev/null | sort -r || true)

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

  printf '\nThis will extract %s onto %s:%s\n' "$(short "${restore_path}")" "${REMOTE_HOST}" "${REMOTE_DIR}"
  printf 'Files with the same path are overwritten; other files already under %s are left untouched.\n' "${REMOTE_DIR}"
  read -rp 'Continue? [y/N] ' _ans
  [[ "${_ans}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

  ssh "${REMOTE_HOST}" "sudo -n tar xzf - -C /srv --numeric-owner" < "${restore_path}"

  echo "Restored $(short "${restore_path}") -> ${REMOTE_HOST}:${REMOTE_DIR}"
fi
