#!/usr/bin/env bash
# Runs the full deploy chain in one shot: bootstrap-user (prompts for the admin
# username created during the Debian install), then site.yml, then verify.yml.
# Prerequisite: scripts/init-workstation.sh has already been run.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

read -rp "Admin username (created during Debian install): " admin_user
if [[ -z "${admin_user}" ]]; then
  echo "No username given — aborting." >&2
  exit 1
fi

echo
echo "Step 1/3: Running ansible bootstrap-user"
ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u "${admin_user}" --ask-pass --ask-become-pass

echo
echo "Step 2/3: Running ansible site"
ansible-playbook playbooks/site.yml

echo
echo "Step 3/3: Running ansible verify"
ansible-playbook playbooks/verify.yml
