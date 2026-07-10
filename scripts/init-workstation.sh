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
FLUX_DEPLOY_KEYS_URL="https://github.com/rene-ott/homelab-cluster/settings/keys"

ok()   { printf '    ✓ %s\n' "$*"; }
warn() { printf '    ! %s\n' "$*" >&2; }
step() { printf '\nStep %s: %s\n' "$1" "$2"; }
ask()  { local ans; read -rp "    Generate? [y/N]: " ans; [[ "${ans,,}" == "y" ]]; }

# Print the HostName configured for a given Host alias in ${SSH_CONFIG}, or nothing. Parses per
# alias (a naive grep would return the first block's HostName for every host).
existing_hostname() {
  [[ -f "${SSH_CONFIG}" ]] || return 0
  awk -v want="$1" '
    $1 == "Host"     { current = ($2 == want) }
    current && $1 == "HostName" { print $2; exit }
  ' "${SSH_CONFIG}"
}

# Append a Host block for <alias> -> <address> to ${SSH_CONFIG} (all homelab hosts use the same
# ansible user and key).
write_ssh_alias() {
  cat >> "${SSH_CONFIG}" <<EOF
Host $1
  HostName $2
  User ansible
  IdentityFile ~/.homelab-secrets/ssh/ansible
EOF
}

# ── Step 1: directory tree ────────────────────────────────────────────────────
step 1 "Create directory structure"
mkdir -p "${SSH_DIR}" "${AGE_DIR}" "${BACKUP_DIR}"
chmod 700 "${SECRETS_DIR}" "${SSH_DIR}" "${AGE_DIR}" "${BACKUP_DIR}"
ok "~/.homelab-secrets/{ssh,age} and ~/.homelab-backups ready"

# ── Step 2: SSH aliases ───────────────────────────────────────────────────────
# This file is fully script-owned, so it is regenerated from scratch each run. atlas (prod) is
# required; atlas-stg (staging) is optional. Existing addresses are kept unless overridden.
step 2 "SSH aliases  (~/.homelab-secrets/ssh/config)"
prod_existing="$(existing_hostname atlas)"
stg_existing="$(existing_hostname atlas-stg)"

if [[ -n "${prod_existing}" ]]; then
  read -rp "    atlas (prod) IP or DNS name (current: ${prod_existing}, leave empty to keep): " prod_addr
else
  read -rp "    atlas (prod) IP or DNS name: " prod_addr
fi
prod_addr="${prod_addr:-${prod_existing}}"

if [[ -n "${stg_existing}" ]]; then
  read -rp "    atlas-stg (staging) IP or DNS name (current: ${stg_existing}, empty to keep, '-' to remove): " stg_addr
else
  read -rp "    atlas-stg (staging) IP or DNS name (optional, leave empty to skip): " stg_addr
fi
stg_addr="${stg_addr:-${stg_existing}}"
[[ "${stg_addr}" == "-" ]] && stg_addr=""

: > "${SSH_CONFIG}"
chmod 600 "${SSH_CONFIG}"
if [[ -n "${prod_addr}" ]]; then
  write_ssh_alias atlas "${prod_addr}"
  ok "atlas -> ${prod_addr}"
else
  warn "no atlas address — prod SSH alias not written; bootstrap-user.yml will fail"
fi
if [[ -n "${stg_addr}" ]]; then
  write_ssh_alias atlas-stg "${stg_addr}"
  ok "atlas-stg -> ${stg_addr}"
else
  ok "atlas-stg not configured (staging skipped)"
fi

if [[ -s "${SSH_CONFIG}" ]]; then
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
  warn "skipped — the flux role will fail without it"
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
  warn "skipped — the flux role will fail without it"
fi

# ── Step 6: register the deploy key on GitHub ────────────────────────────────
# site.yml is non-interactive: it asserts the key can reach the repo and fails with this same
# key and URL rather than prompting. Printing here is what makes that assert actionable.
step 6 "Register the Flux deploy key on GitHub"
if [[ -f "${FLUX_KEY}.pub" ]]; then
  printf '    Add this public key as a deploy key at\n      %s\n' "${FLUX_DEPLOY_KEYS_URL}"
  printf '    Enable "Allow write access" — Flux pushes the gotk-* manifests on first bootstrap.\n\n'
  printf '      %s\n' "$(cat "${FLUX_KEY}.pub")"
else
  warn "no deploy key yet — re-run this script to generate it"
fi

printf '\nDone. Run: ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u <admin> --ask-pass --ask-become-pass\n'
