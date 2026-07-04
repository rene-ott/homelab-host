#!/usr/bin/env bash
# Tears down K3s only (service, data, certs, CNI/iptables, binaries) via
# playbooks/teardown-k3s.yml. Destructive — prompts for confirmation first.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

read -rp "This will delete the K3s cluster, its data, and its certs. Continue? [y/N]: " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

echo
echo "Tearing down K3s"
ansible-playbook playbooks/teardown-k3s.yml -e teardown_confirm=true
