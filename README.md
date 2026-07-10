# homelab-host

Ansible project for a single-node Debian server and its K3s platform. Manages the OS layer and bootstraps Flux CD, which then watches **[homelab-cluster](https://github.com/rene-ott/homelab-cluster)** for all K8s app changes.

## Setup

### 1. Install dependencies

```bash
./scripts/install-deps.sh
```

### 2. Initialise workstation

```bash
./scripts/init-workstation.sh
```

Prompts for the server address and generates missing keys. Safe to re-run. Keys land in:

```
~/.homelab-secrets/ssh/ansible        # Ansible SSH key
~/.homelab-secrets/ssh/flux-deploy    # Flux deploy key
~/.homelab-secrets/age/homelab.agekey # SOPS age key
```

After generating the age key, register its public key in `homelab-cluster` before running `flux_bootstrap`:

1. Add the `age1...` public key to `.sops.yaml` in homelab-cluster (replace `AGE_PUBLIC_KEY_HERE`).
2. Encrypt secrets and commit only the encrypted output:

```bash
SOPS_AGE_KEY_FILE=~/.homelab-secrets/age/homelab.agekey \
  sops -e -i <secret>.sops.yaml
```

### 3. Bootstrap a fresh server

Requires a Debian server with a password-login sudo user.

```bash
ansible-playbook playbooks/bootstrap-user.yml -i inventory/bootstrap.yml -u <admin> --ask-pass --ask-become-pass
```

Creates the `ansible` OS user, installs the public key, and grants passwordless sudo.

### 4. Deploy

```bash
ansible-playbook playbooks/site.yml
```

### 5. Bootstrap Flux

```bash
ansible-playbook playbooks/site.yml --tags k3s
ansible-playbook playbooks/site.yml --tags flux_preflight       # prints deploy public key
ansible-playbook playbooks/site.yml --tags flux_bootstrap
```

Before `flux_bootstrap`: add the deploy public key to homelab-cluster's GitHub deploy keys, and register the age public key in `.sops.yaml` in homelab-cluster:

```bash
SOPS_AGE_KEY_FILE=~/.homelab-secrets/age/homelab.agekey \
  sops -e -i <secret>.sops.yaml   # encrypt before committing
```

## Day-to-day

```bash
ansible-playbook playbooks/site.yml --tags <role>   # single role
ansible-playbook playbooks/site.yml --check --diff  # dry-run
ansible-playbook playbooks/verify.yml               # read-only health check
ansible-lint playbooks/site.yml
```

## Samba share on Windows 11

The `samba` role exposes `/srv/media` as a guest-only share (no password). Windows 10/11 block
"insecure guest logons" by default, so connecting to it fails or prompts for credentials that
don't exist. Windows 11 24H2+ also defaults SMB client signing to *required*, which a guest
session can never satisfy (no key material to sign with) — the client silently aborts the
connection right after the server grants the guest session, showing "Windows cannot access ...".
Run once on each Windows client, as Administrator (prompts for the server IP, also maps
`\\atlas.local\media` as a shortcut for the raw IP):

```powershell
$ip = Read-Host "Server IP"; Add-Content -Path "$env:WinDir\System32\drivers\etc\hosts" -Value "`n$ip atlas.local"; reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f; Set-SmbClientConfiguration -RequireSecuritySignature $false -Force; Restart-Service LanmanWorkstation -Force
```

## Secrets backup

```bash
./scripts/backup-secrets.sh          # interactive backup / restore
```

## Docs

- [`docs/planning/TASKS.md`](docs/planning/TASKS.md) — Now/Next/Someday plan.
- [`CLAUDE.md`](CLAUDE.md) — design, role order, ports.
