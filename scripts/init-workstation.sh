#!/usr/bin/env bash
# One-time workstation initialisation — safe to re-run.
# Creates the ~/.homelab tree, generates missing keys, and writes the SSH alias.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/paths.sh
source "${SCRIPT_DIR}/lib/paths.sh"

main() {
  step 1 "Create base directory structure"
  if [[ ! -f "${HL_GLOBAL_SSH_CONFIG}" ]]; then
    warn "~/.ssh/config not found — create it first (e.g. touch ~/.ssh/config && chmod 600 ~/.ssh/config)"
    exit 1
  fi
  ensure_private_dir "${HL_ROOT}" "${HL_LOCAL}" "${HL_BACKUPS}" "${HL_BACKUPS_LOCAL}" "${HL_BACKUPS_SERVER}"
  ok "~/.homelab/{local,backups/{local,server}} ready"

  step 2 "Host + SSH alias (${HL_SSH_CONFIG})"
  read -rp "    Host alias [${HL_HOST}]: " entered_host
  export HL_HOST="${entered_host:-${HL_HOST}}"
  source "${SCRIPT_DIR}/lib/paths.sh"
  ensure_private_dir "${HL_HOST_LOCAL}"
  write_ssh_host_alias

  step 3 "Ansible SSH key (${HL_BOOTSTRAP_USER_KEY})"
  generate_ssh_key_if_missing "${HL_BOOTSTRAP_USER_KEY}" "${HL_BOOTSTRAP_USER}" "homelab/${HL_HOST}/ansible" "skipped — bootstrap-user.yml will fail without it"

  step 4 "Flux deploy SSH key (${HL_FLUX_AUTH_KEY})"
  generate_ssh_key_if_missing "${HL_FLUX_AUTH_KEY}" "${HL_FLUX_AUTH}" "homelab/${HL_HOST}/flux-deploy" "skipped — flux_auth role will fail without it only if this host runs Flux"
  step 5 "SOPS age key (${HL_FLUX_BOOTSTRAP_AGE_KEY})"
  generate_age_key_if_missing "${HL_FLUX_BOOTSTRAP_AGE_KEY}" "${HL_FLUX_BOOTSTRAP}" "skipped — flux_bootstrap will fail without it only if this host runs Flux"
  cat <<'EOF'

Done. Run:

  ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u <admin> --ask-pass --ask-become-pass

EOF
}

ok() {
  printf '    ✓ %s\n' "$*"
}

warn() {
  printf '    ! %s\n' "$*" >&2
}

step() {
  printf '\nStep %s: %s\n' "$1" "$2"
}

ask_generate() {
  local ans

  read -rp "    Generate? [y/N]: " ans
  [[ "${ans,,}" == "y" ]]
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "missing required command: $1"
    return 1
  }
}

ensure_private_dir() {
  install -d -m 700 "$@"
}

write_global_ssh_include() {
  local include="Include ${HL_SSH_CONFIG}"
  local ssh_dir
  local tmp

  ssh_dir="$(dirname -- "${HL_GLOBAL_SSH_CONFIG}")"
  ensure_private_dir "${ssh_dir}"

  if [[ -f "${HL_GLOBAL_SSH_CONFIG}" ]] &&
     grep -qxF "${include}" "${HL_GLOBAL_SSH_CONFIG}"; then
    ok "~/.ssh/config already includes ${HL_SSH_CONFIG}"
    return
  fi

  tmp="$(mktemp)"

  {
    printf '%s\n' "${include}"
    [[ -f "${HL_GLOBAL_SSH_CONFIG}" ]] && cat "${HL_GLOBAL_SSH_CONFIG}"
  } > "${tmp}"

  install -m 600 "${tmp}" "${HL_GLOBAL_SSH_CONFIG}"
  rm -f "${tmp}"

  ok "Include added to ~/.ssh/config"
}

current_host_addr() {
  [[ -f "${HL_SSH_CONFIG}" ]] || return 0

  awk -v host="Host ${HL_HOST}" '
    $0 == host { in_host=1; next }
    in_host && /^Host / { in_host=0 }
    in_host && /^[[:space:]]*HostName[[:space:]]+/ { print $2; exit }
  ' "${HL_SSH_CONFIG}"
}

remove_host_block() {
  [[ -f "${HL_SSH_CONFIG}" ]] || return 0

  awk -v host="Host ${HL_HOST}" '
    $0 == host { skip=1; next }
    skip && /^Host / { skip=0 }
    !skip { print }
  ' "${HL_SSH_CONFIG}"
}

write_ssh_host_alias() {
  local existing_addr
  local server_addr
  local existing_body
  local tmp

  existing_addr="$(current_host_addr || true)"

  if [[ -n "${existing_addr}" ]]; then
    read -rp "    Server IP or DNS name (current: ${existing_addr}, leave empty to keep): " server_addr
  else
    read -rp "    Server IP or DNS name: " server_addr
  fi

  server_addr="${server_addr:-${existing_addr}}"

  if [[ -z "${server_addr}" ]]; then
    warn "no server address — SSH alias not written; bootstrap-user.yml will fail"
    return
  fi

  existing_body="$(remove_host_block || true)"
  tmp="$(mktemp)"

  {
    [[ -n "${existing_body}" ]] && printf '%s\n\n' "${existing_body}"

    cat <<EOF
Host ${HL_HOST}
  HostName ${server_addr}
  IdentityFile ${HL_BOOTSTRAP_USER_KEY}
EOF
  } > "${tmp}"

  install -m 600 "${tmp}" "${HL_SSH_CONFIG}"
  rm -f "${tmp}"

  ok "written (${HL_HOST} -> ${server_addr})"

  write_global_ssh_include
}

generate_ssh_key_if_missing() {
  local key="$1"
  local dir="$2"
  local comment="$3"
  local skip_message="$4"

  if [[ -f "${key}" ]]; then
    ok "already exists — skipping"
    return
  fi

  ensure_private_dir "${dir}"

  if ask_generate; then
    need_cmd ssh-keygen
    ssh-keygen -t ed25519 -C "${comment}" -f "${key}" -N ""
    ok "generated"
  else
    warn "${skip_message}"
  fi
}

generate_age_key_if_missing() {
  local key="$1"
  local dir="$2"
  local skip_message="$3"

  if [[ -f "${key}" ]]; then
    ok "already exists — skipping"
    return
  fi

  ensure_private_dir "${dir}"

  if ask_generate; then
    need_cmd age-keygen
    age-keygen -o "${key}"
    chmod 600 "${key}"
    ok "generated"
  else
    warn "${skip_message}"
  fi
}

main "$@"
