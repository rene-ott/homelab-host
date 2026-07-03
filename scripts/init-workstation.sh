#!/usr/bin/env bash
# One-time workstation initialisation — safe to re-run.
# Creates ~/.homelab-secrets/ tree, generates missing keys, writes the SSH alias.
set -euo pipefail

SECRETS_DIR="${HOME}/.homelab-secrets"
SSH_DIR="${SECRETS_DIR}/ssh"
AGE_DIR="${SECRETS_DIR}/age"
BACKUP_DIR="${HOME}/.homelab-backups"
SSH_CONFIG="${SSH_DIR}/config"
AGE_KEY="${AGE_DIR}/homelab.agekey"
ANSIBLE_KEY="${SSH_DIR}/ansible"
FLUX_KEY="${SSH_DIR}/flux-deploy"

ok()   { printf '    ✓ %s\n' "$*"; }
warn() { printf '    ! %s\n' "$*" >&2; }
step() { printf '\nStep %s: %s\n' "$1" "$2"; }
ask()  { local ans; read -rp "    Generate? [y/N]: " ans; [[ "${ans,,}" == "y" ]]; }

# ── Step 1: directory tree ────────────────────────────────────────────────────
step 1 "Create directory structure"
mkdir -p "${SSH_DIR}" "${AGE_DIR}" "${BACKUP_DIR}"
chmod 700 "${SECRETS_DIR}" "${SSH_DIR}" "${AGE_DIR}" "${BACKUP_DIR}"
ok "~/.homelab-secrets/{ssh,age} and ~/.homelab-backups ready"

# ── Step 2: SSH alias ─────────────────────────────────────────────────────────
step 2 "SSH alias  (~/.homelab-secrets/ssh/config)"
existing_addr=""
if [[ -f "${SSH_CONFIG}" ]]; then
  existing_addr="$(grep -m1 'HostName' "${SSH_CONFIG}" | awk '{print $2}')"
fi

if [[ -n "${existing_addr}" ]]; then
  read -rp "    Server IP or DNS name (current: ${existing_addr}, leave empty to keep): " server_addr
else
  read -rp "    Server IP or DNS name: " server_addr
fi
server_addr="${server_addr:-${existing_addr}}"

if [[ -n "${server_addr}" ]]; then
  cat > "${SSH_CONFIG}" <<EOF
Host atlas
  HostName ${server_addr}
  User ansible
  IdentityFile ~/.homelab-secrets/ssh/ansible
EOF
  chmod 600 "${SSH_CONFIG}"
  ok "written (${server_addr})"

  GLOBAL_SSH="${HOME}/.ssh/config"
  INCLUDE="Include ~/.homelab-secrets/ssh/config"
  mkdir -p "${HOME}/.ssh" && chmod 700 "${HOME}/.ssh"
  if [[ -f "${GLOBAL_SSH}" ]] && grep -qF "${INCLUDE}" "${GLOBAL_SSH}"; then
    ok "~/.ssh/config already includes ~/.homelab-secrets/ssh/config"
  else
    tmp="$(mktemp)"
    { echo "${INCLUDE}"; [[ -f "${GLOBAL_SSH}" ]] && cat "${GLOBAL_SSH}" || true; } > "${tmp}"
    mv "${tmp}" "${GLOBAL_SSH}"
    chmod 600 "${GLOBAL_SSH}"
    ok "Include added to ~/.ssh/config"
  fi
else
  warn "no server address — SSH alias not written; bootstrap-user.yml will fail"
fi

# ── Step 3: ansible SSH key ───────────────────────────────────────────────────
step 3 "Ansible SSH key  (${ANSIBLE_KEY})"
if [[ -f "${ANSIBLE_KEY}" ]]; then
  ok "already exists — skipping"
elif ask; then
  ssh-keygen -t ed25519 -C "homelab-ansible" -f "${ANSIBLE_KEY}" -N ""
  ok "generated"
else
  warn "skipped — bootstrap-user.yml will fail without it"
fi

# ── Step 4: flux-deploy SSH key ───────────────────────────────────────────────
step 4 "Flux deploy SSH key  (${FLUX_KEY})"
if [[ -f "${FLUX_KEY}" ]]; then
  ok "already exists — skipping"
elif ask; then
  ssh-keygen -t ed25519 -C "homelab/flux-deploy" -f "${FLUX_KEY}" -N ""
  ok "generated"
else
  warn "skipped — flux_auth role will fail without it"
fi

# ── Step 5: SOPS age key ─────────────────────────────────────────────────────
step 5 "SOPS age key  (${AGE_KEY})"
if [[ -f "${AGE_KEY}" ]]; then
  ok "already exists — skipping"
elif ask; then
  age-keygen -o "${AGE_KEY}"
  chmod 600 "${AGE_KEY}"
  ok "generated"
else
  warn "skipped — flux_bootstrap will fail without it"
fi

printf '\nDone. Run: ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u <admin> --ask-pass --ask-become-pass\n'
