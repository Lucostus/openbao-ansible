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

## Decision Log

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-07-30 | Use `specs/` as the SpecOps directory via `.specops.json`. | The repo already had a `specs/` tree from earlier feature planning. |
| 2026-07-30 | Use OpenBao Agent plus Vector directory secrets. | This keeps OpenSearch credentials out of Vector config and avoids exposing them through process environment variables. |
| 2026-07-30 | Keep Vector package repository management outside the first implementation. | The repo policy keeps `openbao_version` as the only desired-version input, and Ansible should not run remote setup scripts. |

## Deviations

None. Implementation has not started.

## Blockers

None. Open questions remain in `requirements.md`.

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

