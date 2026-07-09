#!/usr/bin/env bash
# Interactive entry point for K3s/Flux cluster actions. Loops, prompting for one of:
#   1) bootstrap - site.yml --tags k3s,flux_preflight,flux_bootstrap (install/reconcile the cluster)
#   2) teardown  - teardown-k3s.yml (destructive; prompts for its own confirmation)
#   3) verify    - verify.yml --tags k3s,flux_bootstrap (read-only health check)
#   4) exit
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

while true; do
  echo "Cluster actions:"
  echo "  1) bootstrap - install/reconcile K3s + Flux"
  echo "  2) teardown  - delete the K3s cluster, its data, and its certs"
  echo "  3) verify    - read-only health check of K3s + Flux"
  echo "  4) exit"
  read -rp "Choose an action [1-4]: " choice

  case "${choice}" in
    1)
      echo
      echo "Running ansible site (tags: k3s, flux_preflight, flux_bootstrap)"
      ansible-playbook playbooks/site.yml --tags k3s,flux_preflight,flux_bootstrap
      ;;
    2)
      read -rp "This will delete the K3s cluster, its data, and its certs. Continue? [y/N]: " confirm
      if [[ "${confirm,,}" == "y" ]]; then
        echo
        echo "Tearing down K3s"
        ansible-playbook playbooks/teardown-k3s.yml -e teardown_confirm=true
      else
        echo "Aborted."
      fi
      ;;
    3)
      echo
      echo "Running ansible verify (tags: k3s, flux_bootstrap)"
      ansible-playbook playbooks/verify.yml --tags k3s,flux_bootstrap
      ;;
    4)
      exit 0
      ;;
    *)
      echo "Invalid choice." >&2
      ;;
  esac
  echo
done
