#!/usr/bin/env bash
# Generates a WireGuard client keypair + config for one device (workstation or phone).
# Re-runnable per device — safe to re-run to reprint a config; delete the device's .key
# file first to rotate its keypair.
set -euo pipefail

SECRETS_DIR="${HOME}/.homelab-secrets/wireguard"

require_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: required command not found: $cmd (run ./scripts/install-deps.sh)" >&2; exit 1; }
  done
}

require_cmd wg

mkdir -p "${SECRETS_DIR}"
chmod 700 "${SECRETS_DIR}"

# ── device selection ─────────────────────────────────────────────────────────
printf '\nWhich device is this for?\n'
printf '  1) Windows workstation\n'
printf '  2) Phone / GrapheneOS\n'
read -rp 'Choice [1/2]: ' _choice
case "${_choice}" in
  1) device="workstation"; address="10.10.10.2/32" ;;
  2) device="phone"; address="10.10.10.3/32" ;;
  *) echo "Invalid choice." >&2; exit 1 ;;
esac

key_path="${SECRETS_DIR}/${device}.key"
pub_path="${SECRETS_DIR}/${device}.pub"
conf_path="${SECRETS_DIR}/${device}.conf"

# ── keypair ───────────────────────────────────────────────────────────────────
if [[ -f "${key_path}" ]]; then
  echo "Keypair already exists for '${device}' — reusing $(basename "${key_path}")."
else
  wg genkey | tee "${key_path}" | wg pubkey > "${pub_path}"
  chmod 600 "${key_path}"
  echo "Generated new keypair for '${device}'."
fi

client_private_key="$(<"${key_path}")"
client_public_key="$(<"${pub_path}")"

# ── server details ───────────────────────────────────────────────────────────
read -rp 'Server WireGuard public key (printed by the wireguard role): ' server_public_key
read -rp 'Server endpoint host:port (your static IP or DDNS hostname): ' server_endpoint

if [[ -z "${server_public_key}" || -z "${server_endpoint}" ]]; then
  echo "ERROR: server public key and endpoint are both required." >&2
  exit 1
fi

# ── render config ─────────────────────────────────────────────────────────────
cat > "${conf_path}" <<EOF
[Interface]
PrivateKey = ${client_private_key}
Address = ${address}

[Peer]
PublicKey = ${server_public_key}
Endpoint = ${server_endpoint}
AllowedIPs = 10.10.10.0/24
PersistentKeepalive = 25
EOF
chmod 600 "${conf_path}"

echo "Wrote ${conf_path/#$HOME/\~}"

printf '\n%s public key (paste into wireguard_peers in inventory/group_vars/homelab/vars.yml):\n\n  %s\n\n' \
  "${device}" "${client_public_key}"

# ── device-specific delivery ──────────────────────────────────────────────────
if [[ "${device}" == "workstation" ]]; then
  echo "Copy ${conf_path/#$HOME/\~} into Windows and import it via WireGuard for Windows"
  echo "(\"Import tunnel(s) from file\") — e.g. explorer.exe \"\$(wslpath -w "${conf_path}")\""
else
  require_cmd qrencode
  echo "Scan this QR code with the official WireGuard Android app on the GrapheneOS phone:"
  echo
  qrencode -t ansiutf8 < "${conf_path}"
fi
