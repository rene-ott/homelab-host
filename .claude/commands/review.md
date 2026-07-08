Review the current working tree.

Do not edit files.

Read:

- `CLAUDE.md`
- `docs/planning/TASKS.md`

Inspect the diff and report:

1. Whether the diff implements only the current `## Now` task
2. Any scope creep into `## Next` or `## Someday`
3. Any violation of `CLAUDE.md`
4. Any likely Ansible or idempotency issue
5. Any secret-handling risk
6. Any firewall/port ownership violation
7. Any missing verification

Pay special attention to:

- K3s apps must not be added to this Ansible repo
- host-level ports must live only in `inventory/group_vars/homelab/vars.yml`
- secrets must not be committed in plaintext
- private SSH keys must not be copied except the documented Flux deploy-key carve-out
- `security` and `firewall` must remain always-on
- toggleable roles must use `<role>_enabled | default(true) | bool`
- disabled roles must not run their own asserts
- no `LOG.md`, changelogs, `architecture.md`, per-task files, migration plans, or TODO inventories

Return:

- `OK to verify` or `Needs changes`
- blockers
- non-blocking notes
- exact verification commands