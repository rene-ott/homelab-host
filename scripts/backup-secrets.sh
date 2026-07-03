#!/usr/bin/env bash
set -euo pipefail

SECRETS_DIR="${HOME}/.homelab-secrets"
KEY_DIR="${SECRETS_DIR}/ssh"
AGE_DIR="${SECRETS_DIR}/age"
AGE_KEY="${AGE_DIR}/homelab.agekey"
SSH_ALIAS="${KEY_DIR}/config"
SSH_CONFIG="${HOME}/.ssh/config"
BACKUP_DIR="${HOME}/.homelab-backups"
INCLUDE_LINE="Include ~/.homelab-secrets/ssh/config"

SECRET_FILES=(
  "${KEY_DIR}/ansible"
  "${KEY_DIR}/ansible.pub"
  "${KEY_DIR}/flux-deploy"
  "${KEY_DIR}/flux-deploy.pub"
  "${SSH_ALIAS}"
  "${AGE_KEY}"
)

require_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: required command not found: $cmd" >&2; exit 1; }
  done
}

short() { echo "${1/#$HOME/\~}"; }

# ── top-level menu ────────────────────────────────────────────────────────────
printf '\nHomelab secrets — what do you want to do?\n'
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
  require_cmd tar age base64

  local_missing=()
  for f in "${SECRET_FILES[@]}"; do [[ -f "$f" ]] || local_missing+=("$f"); done
  if [[ ${#local_missing[@]} -gt 0 ]]; then
    echo "ERROR: missing required secret files:" >&2
    printf '  %s\n' "${local_missing[@]}" >&2
    exit 1
  fi

  mkdir -p "${BACKUP_DIR}"

  existing_age="$(compgen -G "${BACKUP_DIR}/*.tar.gz.age" 2>/dev/null | head -1 || true)"
  existing_b64="$(compgen -G "${BACKUP_DIR}/*.b64"       2>/dev/null | head -1 || true)"

  if [[ -n "${existing_age}" || -n "${existing_b64}" ]]; then
    printf '\nBackup already exists:\n'
    [[ -n "${existing_age}" ]] && printf '  %s\n' "$(short "${existing_age}")"
    [[ -n "${existing_b64}" ]] && printf '  %s\n' "$(short "${existing_b64}")"
    read -rp 'Overwrite? [y/N] ' _ans
    [[ "${_ans}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
    rm -f "${existing_age}" "${existing_b64}"
  fi

  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_path="${BACKUP_DIR}/${timestamp}.tar.gz.age"
  b64_path="${BACKUP_DIR}/${timestamp}.b64"

  tmpdir="$(mktemp -d)"
  trap "rm -rf '${tmpdir}'" EXIT

  mkdir -p "${tmpdir}/stage/ssh" "${tmpdir}/stage/age"
  cp "${KEY_DIR}/ansible"         "${tmpdir}/stage/ssh/ansible"
  cp "${KEY_DIR}/ansible.pub"     "${tmpdir}/stage/ssh/ansible.pub"
  cp "${KEY_DIR}/flux-deploy"     "${tmpdir}/stage/ssh/flux-deploy"
  cp "${KEY_DIR}/flux-deploy.pub" "${tmpdir}/stage/ssh/flux-deploy.pub"
  cp "${SSH_ALIAS}"               "${tmpdir}/stage/ssh/config"
  cp "${AGE_KEY}"                 "${tmpdir}/stage/age/homelab.agekey"

  plaintext="${tmpdir}/homelab-secrets.tar.gz"
  tar -czf "${plaintext}" -C "${tmpdir}/stage" \
    ssh/ansible ssh/ansible.pub ssh/flux-deploy ssh/flux-deploy.pub ssh/config age/homelab.agekey

  age -p -o "${backup_path}" "${plaintext}"
  base64 "${backup_path}" > "${b64_path}"

  printf '\nBacked up:\n'
  for f in "${SECRET_FILES[@]}"; do printf '  %s\n' "$(short "$f")"; done
  printf '→ %s\n' "$(short "${backup_path}")"
  printf '→ %s\n\n' "$(short "${b64_path}")"
  printf 'Base64:\n'
  cat "${b64_path}"
  printf '\nLast line: %s\n' "$(tail -1 "${b64_path}")"
fi

# ── restore ───────────────────────────────────────────────────────────────────
if [[ "${action}" == "restore" ]]; then
  require_cmd tar age

  tmpdir="$(mktemp -d)"
  trap "rm -rf '${tmpdir}'" EXIT
  plaintext="${tmpdir}/homelab-secrets.tar.gz"

  mkdir -p "${BACKUP_DIR}"
  mapfile -t age_files < <(compgen -G "${BACKUP_DIR}/*.tar.gz.age" 2>/dev/null || true)
  mapfile -t b64_files < <(compgen -G "${BACKUP_DIR}/*.b64"       2>/dev/null || true)

  sources=()
  source_labels=()
  [[ ${#age_files[@]} -eq 1 ]] && { sources+=("age"); source_labels+=("$(short "${age_files[0]}")"); }
  [[ ${#b64_files[@]} -eq 1 ]] && { sources+=("b64"); source_labels+=("$(short "${b64_files[0]}")"); }
  sources+=("paste"); source_labels+=("Paste base64")

  if [[ ${#age_files[@]} -gt 1 || ${#b64_files[@]} -gt 1 ]]; then
    echo "ERROR: multiple backups found — delete extras manually, keeping only one pair." >&2
    exit 1
  fi

  printf '\nRestore source:\n'
  for i in "${!sources[@]}"; do
    printf '  %d) %s\n' "$((i+1))" "${source_labels[$i]}"
  done
  read -rp "Choice [1-${#sources[@]}]: " _src_choice
  _src_idx=$(( _src_choice - 1 ))
  [[ "${_src_idx}" -ge 0 && "${_src_idx}" -lt "${#sources[@]}" ]] || { echo "Invalid choice." >&2; exit 1; }
  src_type="${sources[${_src_idx}]}"

  case "${src_type}" in
    age)
      age -d -o "${plaintext}" "${age_files[0]}"
      backup_label="$(short "${age_files[0]}")"
      ;;
    b64)
      require_cmd base64
      decoded="${tmpdir}/decoded.tar.gz.age"
      base64 -d "${b64_files[0]}" > "${decoded}"
      age -d -o "${plaintext}" "${decoded}"
      backup_label="$(short "${b64_files[0]}")"
      ;;
    paste)
      require_cmd base64
      printf 'Paste base64 then press Enter, Ctrl+D:\n'
      decoded="${tmpdir}/decoded.tar.gz.age"
      base64 -d - > "${decoded}"
      age -d -o "${plaintext}" "${decoded}"
      backup_label="pasted input"
      ;;
  esac

  tar -xzf "${plaintext}" -C "${tmpdir}"

  mkdir -p "${HOME}/.ssh"   && chmod 0700 "${HOME}/.ssh"
  mkdir -p "${KEY_DIR}"     && chmod 0700 "${KEY_DIR}"
  mkdir -p "${AGE_DIR}"     && chmod 0700 "${AGE_DIR}"

  SRCS=(
    "${tmpdir}/ssh/ansible"
    "${tmpdir}/ssh/ansible.pub"
    "${tmpdir}/ssh/flux-deploy"
    "${tmpdir}/ssh/flux-deploy.pub"
    "${tmpdir}/ssh/config"
    "${tmpdir}/age/homelab.agekey"
  )
  DSTS=(
    "${KEY_DIR}/ansible"
    "${KEY_DIR}/ansible.pub"
    "${KEY_DIR}/flux-deploy"
    "${KEY_DIR}/flux-deploy.pub"
    "${SSH_ALIAS}"
    "${AGE_KEY}"
  )
  MODES=(0600 0644 0600 0644 0600 0600)

  restored=(); overwritten=(); unchanged=(); skipped=()

  for i in "${!SRCS[@]}"; do
    src="${SRCS[$i]}"; dst="${DSTS[$i]}"; mode="${MODES[$i]}"
    if [[ ! -f "${dst}" ]]; then
      cp "${src}" "${dst}"; chmod "${mode}" "${dst}"
      restored+=("${dst}")
    else
      src_hash="$(sha256sum "${src}" | cut -d' ' -f1)"
      dst_hash="$(sha256sum "${dst}" | cut -d' ' -f1)"
      if [[ "${src_hash}" == "${dst_hash}" ]]; then
        unchanged+=("${dst}")
      else
        read -rp "  Overwrite $(short "${dst}")? [y/N] " _ans
        if [[ "${_ans}" =~ ^[Yy]$ ]]; then
          cp "${src}" "${dst}"; chmod "${mode}" "${dst}"
          overwritten+=("${dst}")
        else
          skipped+=("${dst}")
        fi
      fi
    fi
  done

  touch "${SSH_CONFIG}"; chmod 0600 "${SSH_CONFIG}"
  config_added=0
  if ! grep -qF "${INCLUDE_LINE}" "${SSH_CONFIG}"; then
    tmp_cfg="$(mktemp)"
    { echo "${INCLUDE_LINE}"; cat "${SSH_CONFIG}"; } > "${tmp_cfg}"
    mv "${tmp_cfg}" "${SSH_CONFIG}"; chmod 0600 "${SSH_CONFIG}"
    config_added=1
  fi

  printf '\nRestored from %s:\n' "${backup_label}"
  for f in "${restored[@]+"${restored[@]}"}";       do printf '  + %s\n' "$(short "$f")"; done
  for f in "${overwritten[@]+"${overwritten[@]}"}"; do printf '  ~ %s\n' "$(short "$f")"; done
  for f in "${unchanged[@]+"${unchanged[@]}"}";     do printf '  = %s (unchanged)\n' "$(short "$f")"; done
  for f in "${skipped[@]+"${skipped[@]}"}";         do printf '  - %s (skipped)\n' "$(short "$f")"; done
  [[ "${config_added}" -eq 1 ]] \
    && printf '  + %s (Include line added)\n'           "$(short "${SSH_CONFIG}")" \
    || printf '  = %s (Include line already present)\n' "$(short "${SSH_CONFIG}")"
fi
