#!/usr/bin/env bash
# Removes everything created by init-workstation.sh.
# WARNING: deletes all local homelab keys — back up first if needed.
set -euo pipefail

SECRETS_DIR="${HOME}/.homelab-secrets"
BACKUP_DIR="${HOME}/.homelab-backups"
SSH_CONFIG="${HOME}/.ssh/config"
INCLUDE_LINE="Include ~/.homelab-secrets/ssh/config"

printf 'This will permanently delete:\n'
printf '  %s\n' "${SECRETS_DIR}"
printf '  Include line from %s\n' "${SSH_CONFIG}"
printf '\nBack up first if needed: ./scripts/backup-secrets.sh\n\n'
read -rp 'Continue? [y/N] ' ans
[[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 0; }

if [[ -d "${SECRETS_DIR}" ]]; then
  rm -rf "${SECRETS_DIR}"
  printf '  ✓ removed %s\n' "${SECRETS_DIR}"
else
  printf '  - %s not found — skipping\n' "${SECRETS_DIR}"
fi

if [[ -f "${SSH_CONFIG}" ]] && grep -qF "${INCLUDE_LINE}" "${SSH_CONFIG}"; then
  sed -i "\|^${INCLUDE_LINE}$|d" "${SSH_CONFIG}"
  printf '  ✓ removed Include line from %s\n' "${SSH_CONFIG}"
else
  printf '  - Include line not found in %s — skipping\n' "${SSH_CONFIG}"
fi

if [[ -d "${BACKUP_DIR}" ]]; then
  read -rp "  Also delete backups (${BACKUP_DIR})? [y/N] " _ans
  if [[ "${_ans,,}" == "y" ]]; then
    rm -rf "${BACKUP_DIR}"
    printf '  ✓ removed %s\n' "${BACKUP_DIR}"
  else
    printf '  - backups kept at %s\n' "${BACKUP_DIR}"
  fi
fi
