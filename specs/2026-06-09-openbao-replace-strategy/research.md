# Research Progress: OpenBao Replace Existing Strategy

**Started:** 2026-06-09
**Status:** complete

---

## Objective

Define and implement a destructive OpenBao replacement workflow for this
Ansible repository. Operators need a group-var-controlled way to delete
Ansible-managed OpenBao state and recreate a three-node HA cluster from
scratch, while preserving externally uploaded bootstrap TLS and CA inputs.

---

## Defined Terms

| Term | Definition |
|------|------------|
| Managed footprint | OpenBao files/directories Ansible creates or owns, including config, data, Raft, seal key, installed listener TLS copies, logs, package cache, systemd units, Agent config/state, generated node-subCA bootstrap output, and generated controller artifacts. |
| External operator inputs | Inventory, `group_vars`, vaulted vars, uploaded bootstrap TLS source files, uploaded node sub-CA cert/key material, issuer directories, and `files/bootstrap-tls/`. |
| OS basics | Installed packages, service user/group, firewalld rules, and SELinux port rules. These remain installed/configured. |
| Controller artifacts | The selected `openbao_secure_artifacts_dir`; replacement deletes this entire directory, including init JSON, static seal key artifact, Agent AppRole artifacts, generated self-signed certs, and snapshots. |

---

## Findings

### Finding 1: Existing token failure cause
**Date:** 2026-06-09

`roles/openbao_common/tasks/validate_raft_health.yml` requires either
`openbao_operator_token` or the local init artifact before authenticated Raft
validation. The init artifact lives under ignored `secure-artifacts/`, so fresh
controller workspaces such as CI do not have it unless explicitly restored.

### Finding 2: Existing reset support
**Date:** 2026-06-09

The only existing reset helper is `lab/scripts/openbao-lab-reset.sh`, which is
Docker-lab-specific. No production replace/reset playbook or group variable
exists.

### Finding 3: OpenBao initialized state location
**Date:** 2026-06-09

Deleting the controller init JSON alone does not recreate the cluster. OpenBao
initialized state lives remotely in the Raft data path and static seal material,
with additional managed state under config, TLS, log, package cache, and Agent
paths.

---

## Decisions

### Decision 1: Spec location
**Date:** 2026-06-09

**Decision:** Store the spec under
`specs/2026-06-09-openbao-replace-strategy/`.
**Rationale:** The repository had no existing spec folder convention; a dated
folder keeps the destructive workflow design isolated and discoverable.

### Decision 2: Operator interface
**Date:** 2026-06-09

**Decision:** Use a group variable named `openbao_replace_existing`.
**Rationale:** The user requested group-var control rather than a separate
script or playbook-only interface.

### Decision 3: Replacement semantics
**Date:** 2026-06-09

**Decision:** When `openbao_replace_existing: true`, every `site.yml` run
replaces the selected deployment.
**Rationale:** The user explicitly chose every-run replacement over
once-per-generation behavior.

### Decision 4: Preservation scope
**Date:** 2026-06-09

**Decision:** Delete everything Ansible creates, but preserve operator-created
or uploaded TLS/CA inputs.
**Rationale:** Operators should not need to recopy bootstrap listener
certificates or sub-CA material after replacement.

### Decision 5: OS resource scope
**Date:** 2026-06-09

**Decision:** Keep OS basics: packages, service user/group, firewalld rules,
and SELinux rules.
**Rationale:** Replacement should recreate OpenBao state without turning into a
full OS uninstall.

### Decision 6: Controller artifact scope
**Date:** 2026-06-09

**Decision:** Delete the selected `openbao_secure_artifacts_dir`.
**Rationale:** Replacement should remove init output, generated seal material,
Agent artifacts, generated certs, and snapshots for the selected target.

### Decision 7: Playbook scope
**Date:** 2026-06-09

**Decision:** `site.yml` honors replacement; `upgrade.yml` refuses when
replacement is enabled.
**Rationale:** Upgrade must not become a hidden destroy/recreate path.

### Decision 8: Execution mode
**Date:** 2026-06-09

**Decision:** Use three parallel subagents: implementation, docs, and
test/lab, followed by one final reconciliation/review pass.
**Rationale:** The user selected three parallel subagents for execution.

---

## Open Questions

All questions needed for this implementation are answered.
