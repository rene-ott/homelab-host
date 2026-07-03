#!/usr/bin/env bash
# Installs workstation tooling after a fresh clone. Idempotent — safe to re-run.
# Does NOT touch secrets, SSH keys, or Age keys — those are Ansible's job.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

have() { command -v "$1" >/dev/null 2>&1; }

ver_of() {
  local raw
  raw="$($1 2>&1 | head -1)"
  grep -oE '[0-9]+\.[0-9]+[.p0-9a-z]*' <<< "$raw" | head -1
}

row() { printf '  %-22s %-18s %-14s %-14s %s\n' "$1" "$2" "$3" "$4" "$5"; }

loc_of() { command -v "$1" 2>/dev/null || echo "unknown"; }

printf 'Installing dependencies:\n'

# ── apt packages ──────────────────────────────────────────────────────────────
declare -A _apt_status
pkgs=(ansible ansible-lint openssh-client age curl)
missing=()

for pkg in "${pkgs[@]}"; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    _apt_status[$pkg]="already installed"
  else
    missing+=("$pkg")
    _apt_status[$pkg]="installed"
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  sudo apt-get update -qq
  sudo apt-get install -qq -y --no-install-recommends "${missing[@]}" >/dev/null 2>&1
fi

declare -A _ver_cmd=(
  [ansible]="ansible --version"
  [ansible-lint]="ansible-lint --version"
  [age]="age --version"
  [curl]="curl --version"
  [openssh-client]="ssh -V"
)
declare -A _bin=(
  [ansible]="ansible"
  [ansible-lint]="ansible-lint"
  [age]="age"
  [curl]="curl"
  [openssh-client]="ssh"
)
for pkg in "${pkgs[@]}"; do
  row "$pkg" "${_apt_status[$pkg]}" "$(ver_of "${_ver_cmd[$pkg]}")" "apt" "$(loc_of "${_bin[$pkg]}")"
done

# ── sops ──────────────────────────────────────────────────────────────────────
if have sops; then
  sops_status="already installed"
else
  sops_status="installed"
  SOPS_VERSION="3.13.1"
  ARCH="$(dpkg --print-architecture)"
  case "$ARCH" in
    amd64) SOPS_ARCH="amd64" ;;
    arm64) SOPS_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
  esac
  SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${SOPS_ARCH}"
  curl -fsSL "$SOPS_URL" -o /tmp/sops
  chmod +x /tmp/sops
  sudo mv /tmp/sops /usr/local/bin/sops
fi
row "sops" "$sops_status" "$(ver_of "sops --version")" "github" "$(loc_of sops)"

# ── ansible-galaxy collections ────────────────────────────────────────────────
_before_cols="$(ansible-galaxy collection list 2>/dev/null || true)"
ansible-galaxy collection install -r "$REPO_ROOT/requirements.yml" >/dev/null 2>&1
_after_cols="$(ansible-galaxy collection list 2>/dev/null || true)"
_col_path="$(grep '^#' <<< "$_after_cols" | head -1 | sed 's/^# //')"

while IFS= read -r col; do
  [[ -z "$col" ]] && continue
  ver="$(awk -v c="$col" '$1==c{print $2; exit}' <<< "$_after_cols")"
  if awk -v c="$col" '$1==c{found=1; exit} END{exit !found}' <<< "$_before_cols"; then
    col_status="already installed"
  else
    col_status="installed"
  fi
  row "$col" "$col_status" "${ver:-unknown}" "ansible-galaxy" "${_col_path:-unknown}"
done < <(grep -E '^\s*-\s*name:' "$REPO_ROOT/requirements.yml" | sed 's/.*name:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')
