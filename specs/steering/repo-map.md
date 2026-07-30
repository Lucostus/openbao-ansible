---
inclusion: always
generatedBy: specops
updated: 2026-07-30T12:02:49Z
---

# Repo Map

Generated from the tracked file list on 2026-07-30.

## Entry Points

- `playbooks/site.yml` validates the selected target, optionally replaces an
  existing deployment, converges OpenBao server state, optionally configures
  PKI and OpenBao Agent, and runs final validation.
- `playbooks/upgrade.yml` performs controlled rolling upgrades after health,
  version, and Raft checks.
- `playbooks/diagnose_node_subca.yml` diagnoses node-hosted subordinate CA
  inputs without changing the cluster.

## Configuration

- `group_vars/all/openbao_defaults.yml` holds the complete default variable
  surface.
- `group_vars/rhel10/main.yml`, `group_vars/openbao-prod/main.yml`, and
  `group_vars/openbao-test/main.yml` are operator-facing target inputs.
- `group_vars/**/vault.yml` files are intentionally ignored for real secrets.

## Roles

- `roles/openbao_common/` handles host preparation, variable loading, target
  validation, TLS/seal material, replacement, and validation.
- `roles/openbao_server/` renders `openbao.hcl`, systemd hardening, and the
  OpenBao server unit.
- `roles/openbao_bootstrap/` initializes OpenBao and persists controller
  artifacts.
- `roles/openbao_pki/` manages PKI mounts, issuers, roles, EAB artifacts, and
  current OpenBao Agent AppRole artifacts.
- `roles/openbao_agent/` renders OpenBao Agent configuration and templates,
  installs the Agent service, and validates Agent-managed listener certs.
- `roles/openbao_upgrade/` handles rolling package updates and post-upgrade
  validation.

## Documentation And Lab

- `README.md` is the quick operator path.
- `docs/variables.md` is the detailed variable reference.
- `docs/upgrade.md` describes upgrade behavior.
- `lab/` provides Docker-backed RHEL-like validation helpers.

