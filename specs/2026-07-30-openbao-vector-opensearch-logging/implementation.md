# Implementation Journal

## Phase 1 Context Summary

- Config status: `.specops.json` was absent. This run added a minimal config
  pointing SpecOps at the existing `specs/` directory.
- SpecOps version: 1.8.0.
- Context recovery: existing non-SpecOps replace strategy notes were found at
  `specs/2026-06-09-openbao-replace-strategy/`.
- Steering loaded: product, tech, structure, dependencies, and repo map created
  under `specs/steering/`.
- Memory loaded: initialized under `specs/memory/`; no prior completed SpecOps
  memories.
- Detected vertical: infrastructure.
- Project state: brownfield Ansible repository.
- Scope assessment: single spec chosen. The request spans Vector, OpenBao Agent
  templates, docs, and lab validation, but these changes are tightly coupled by
  one operator-facing feature and one acceptance path.
- Affected files expected:
  - `.gitignore`
  - `.specops.json`
  - `group_vars/all/openbao_defaults.yml`
  - `playbooks/site.yml`
  - `playbooks/upgrade.yml`
  - `roles/openbao_common/tasks/preflight.yml`
  - `roles/openbao_common/tasks/replace_existing.yml`
  - `roles/openbao_common/tasks/validate_site.yml`
  - `roles/openbao_pki/tasks/configure_agent_identity.yml`
  - `roles/openbao_pki/tasks/main.yml`
  - `roles/openbao_agent/tasks/main.yml`
  - `roles/openbao_agent/templates/openbao-agent.hcl.j2`
  - `roles/openbao_agent/templates/openbao-agent.service.j2`
  - `roles/openbao_agent/templates/openbao-agent-listener-cert-hook.py.j2`
  - `roles/openbao_vector/**`
  - `README.md`
  - `docs/variables.md`
  - `lab/**`

## Phase 2 Completion Summary

Draft requirements, design, tasks, dependency audit, and evaluation artifacts
were created for Vector-based OpenBao log forwarding to OpenSearch.

Key requirements decided:

- Vector is disabled by default.
- Runtime OpenSearch credentials come from OpenBao via OpenBao Agent-rendered
  files.
- Vector uses its `SECRET[...]` directory backend rather than plaintext config
  or environment variables.
- Vector can be enabled in bootstrap certificate mode without forcing listener
  certificate renewal.
- Replacement removes managed Vector runtime state but does not uninstall the
  package.

Key design decisions made:

- Use Vector's `elasticsearch` sink for OpenSearch.
- Use Vector file source for audit logs and journald source for service logs.
- Refactor Agent enablement into service-level and listener-cert-specific
  booleans.
- Move Agent AppRole identity creation out of the PKI-only path.
- Do not execute Vector setup scripts from Ansible.

Dependencies identified:

- Net-new OS package: `vector`, approved for this feature with constraints in
  `design.md` and `dependency-audit.md`.

## Phase 3 Completion Summary

Implemented Vector-based OpenBao log forwarding with OpenBao Agent-rendered
OpenSearch credentials.

Completed changes:

- Added the `openbao_vector_*` variable surface and preflight validation.
- Split OpenBao Agent enablement into listener-certificate and Vector-secret
  feature flags while keeping one Agent service.
- Moved AppRole identity provisioning into shared OpenBao common tasks so
  Vector-only Agent use is supported.
- Added Vector secret templates and an Agent hook that validates rendered
  credentials, fixes permissions, and restarts Vector when the service is
  active.
- Added `roles/openbao_vector` to install Vector, render
  `/etc/vector/vector.yaml`, validate it, confirm audit-log readability, and
  manage `vector.service`.
- Extended replacement cleanup to stop Vector and remove managed Vector config,
  state, and rendered secret paths while leaving packages and operator inputs
  intact.
- Added a Docker lab OpenSearch-compatible mock target and lab documentation for
  seeded OpenSearch credentials.

Implementation notes:

- Vector uses the `elasticsearch` sink with OpenSearch compatibility and
  Vector `SECRET[...]` references. OpenSearch credentials are not rendered into
  `vector.yaml`.
- OpenBao audit-log file permissions are managed with
  `openbao_audit_log_mode`, defaulting to `0640`. This is a filesystem
  permission only, not an OpenBao audit device HCL option.
- The Vector role performs a late readability check with `runuser` so lab and
  production hosts fail clearly if the Vector service account cannot read the
  managed audit log.
- Optional secret seeding writes the OpenSearch credential into OpenBao KV v2
  with `no_log: true`; production operators can instead pre-create that secret.

Validation completed:

- `ansible-playbook --syntax-check playbooks/site.yml`
- `ansible-playbook --syntax-check playbooks/upgrade.yml`
- `ansible-inventory --graph`
- `ansible-lint`
- `yamllint .`
- `docker compose -f lab/compose.yml config`
- `git diff --check`
- Docker daemon check: client `29.6.1`, server `28.5.1`.
- Default Docker lab `site` run completed with OpenBao healthy, OpenBao Agent
  inactive, and Vector inactive.
- Docker lab `upgrade` run completed successfully.
- Vector-enabled Docker lab `site` run completed with OpenBao healthy, OpenBao
  Agent active, and Vector active on all three nodes.
- Repeated Docker lab replacement with Vector and seeded credentials completed
  twice and returned OpenBao to healthy state.
- Mock OpenSearch ingestion was verified after an authenticated OpenBao request:
  total events `4012`, audit events `291`, service events `3721`.

## Summary

All 8 implementation tasks are completed. The final feature adds disabled by
default Vector log forwarding, OpenBao Agent-backed OpenSearch credential
rendering, shared Agent AppRole identity provisioning, replacement cleanup for
managed Vector state, and Docker lab support with a mock OpenSearch-compatible
target. Static validation and live Docker lab validation passed.

## Decision Log

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-07-30 | Use `specs/` as the SpecOps directory via `.specops.json`. | The repo already had a `specs/` tree from earlier feature planning. |
| 2026-07-30 | Use OpenBao Agent plus Vector directory secrets. | This keeps OpenSearch credentials out of Vector config and avoids exposing them through process environment variables. |
| 2026-07-30 | Keep Vector package repository management outside the first implementation. | The repo policy keeps `openbao_version` as the only desired-version input, and Ansible should not run remote setup scripts. |
| 2026-07-30 | Manage audit-log readability through file permissions, not OpenBao audit HCL. | Existing OpenBao audit devices failed startup when an unsupported `mode` option appeared in config but not in persisted audit-device state. |

## Deviations

No unresolved deviations.

One implementation adjustment was made during lab validation: audit log access is
managed by Ansible filesystem permissions and a Vector readability probe rather
than by adding a `mode` option to the OpenBao audit device stanza.

## Blockers

None.

## Documentation Review

| File | Status | Notes |
| --- | --- | --- |
| `README.md` | Updated | Added Vector enablement, secret, package, replacement, and validation guidance. |
| `docs/variables.md` | Updated | Added operator-facing Vector and audit-log mode variable documentation. |
| `lab/README.md` | Updated | Added Vector/OpenSearch mock lab commands and replacement validation flow. |
| `specs/2026-07-30-openbao-vector-opensearch-logging/tasks.md` | Updated | Marked all implementation tasks and acceptance criteria complete. |

## Reference Validation

- Official Vector docs confirm the file source, journald source, secret
  backends, Elasticsearch/OpenSearch sink, and `vector validate` command.
- Official OpenBao docs confirm Agent templates, AppRole auto-auth, AppRole
  machine auth usage, and KV v2 policy path requirements.
- Code-grounded validation confirms this repo already has audit file defaults,
  Agent AppRole artifacts, Agent template rendering, replacement cleanup, and
  site/upgrade playbook boundaries that the design can extend.

## Session Log

- 2026-07-30T12:02:49Z: Initialized SpecOps configuration and steering files.
- 2026-07-30T12:02:49Z: Created draft spec artifacts for review.
- 2026-07-30T12:17:52Z: Entered implementation and started Task 1.
- 2026-07-30T12:30:00Z: Implemented defaults, shared Agent identity management, Agent template refactor, Vector role, playbook wiring, replacement cleanup, and early syntax checks.
- 2026-07-30T13:12:18Z: Completed static validation, Docker lab validation, Vector ingestion checks, and spec closeout updates.
