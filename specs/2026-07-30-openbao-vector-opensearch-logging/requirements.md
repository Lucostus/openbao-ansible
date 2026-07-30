# Requirements

## Overview

Add optional Vector-based log forwarding for OpenBao audit logs and OpenBao
service logs. When enabled, each OpenBao node runs Vector locally, collects the
existing file audit log and relevant systemd journal units, and forwards those
events to OpenSearch.

OpenSearch credentials must not be stored in the Vector configuration,
committed files, or GitLab artifacts. The default credential flow uses OpenBao
Agent to authenticate to OpenBao with a per-node AppRole, render the selected
OpenBao KV secret into local Vector secret files, and let Vector resolve those
files through its `SECRET[...]` secret backend support.

## Scope

In scope:

- Add a disabled-by-default Vector forwarding feature to `playbooks/site.yml`.
- Collect `openbao_audit_log_file` through Vector's file source.
- Collect normal OpenBao service logs through Vector's journald source for
  `openbao.service` and, when the Agent is active, `openbao-agent.service`.
- Forward events to OpenSearch through Vector's Elasticsearch sink with
  OpenSearch compatibility settings.
- Use OpenBao Agent and AppRole to render OpenSearch credentials from OpenBao
  into local files readable by Vector.
- Support bootstrap certificate mode plus Vector secrets without forcing
  listener certificate renewal.
- Keep replacement semantics complete by removing managed Vector config,
  state, and rendered secrets when `openbao_replace_existing=true`.
- Document operator inputs, OpenBao secret prerequisites, and lab validation.

Out of scope:

- Provisioning OpenSearch itself outside the lab.
- OpenSearch dashboards, index templates, ILM/ISM policies, or alerting.
- Native Vector aggregation tiers.
- Shipping host metrics.
- Long-term root token or operator token management.
- Automatically creating production OpenSearch users.
- Uninstalling the Vector package during replacement.

## Assumptions

- The first implementation targets self-managed or managed OpenSearch using
  basic authentication.
- Operators create the OpenSearch user/password in OpenBao KV v2 before
  enabling the feature, or provide vaulted seed values explicitly for lab or
  replacement workflows.
- The production package repository for `vector` is made available to RHEL
  hosts by the operator or platform baseline. The role installs the `vector`
  package but does not pipe remote setup scripts into a shell.
- Runtime secrets may exist on disk as root-owned, group-readable rendered
  files for Vector. They must not be tracked or fetched back to the controller.
- OpenBao audit events are JSON lines when emitted by the file audit device.

## Operator Interface

Default:

```yaml
openbao_vector_enabled: false
```

Minimal enabled example:

```yaml
openbao_vector_enabled: true
openbao_vector_opensearch_endpoints:
  - https://opensearch.example.com:9200
openbao_vector_opensearch_secret_mount: secret
openbao_vector_opensearch_secret_path: observability/opensearch/openbao-vector
```

Expected OpenBao KV v2 secret shape:

```text
secret/data/observability/opensearch/openbao-vector
```

Fields:

```yaml
username: openbao-vector
password: change-me
```

Optional replacement/lab seed path:

```yaml
openbao_vector_seed_opensearch_secret: true
openbao_vector_opensearch_secret_data:
  username: openbao-vector
  password: "{{ vaulted_openbao_vector_opensearch_password }}"
```

The seed variable must live in an encrypted vault or lab-only vars. It is a
convenience for repeatable replacement runs; runtime Vector still obtains the
credentials through OpenBao Agent-rendered files.

## User Stories

### Story 1: Disabled by default

As an operator, I want the current OpenBao deployment and upgrade behavior to
remain unchanged unless I enable Vector, so that existing clusters are not
modified unexpectedly.

Acceptance criteria:

- THE SYSTEM SHALL define `openbao_vector_enabled: false` by default.
- WHILE `openbao_vector_enabled=false` THE SYSTEM SHALL NOT install Vector,
  create Vector config, start Vector, or require OpenBao Agent for logging.
- WHILE `openbao_vector_enabled=false` THE SYSTEM SHALL keep
  `playbooks/site.yml` and `playbooks/upgrade.yml` behavior equivalent to the
  current convergent behavior.

### Story 2: Forward audit and service logs

As an operator, I want OpenBao audit logs and service logs forwarded to
OpenSearch, so that security and operational events are queryable outside the
nodes.

Acceptance criteria:

- WHERE `openbao_vector_enabled=true` THE SYSTEM SHALL install and configure a
  local Vector service on every selected OpenBao node.
- WHERE `openbao_vector_enabled=true` THE SYSTEM SHALL configure a Vector file
  source for `openbao_audit_log_file`.
- WHERE `openbao_vector_enabled=true` THE SYSTEM SHALL configure a Vector
  journald source for `openbao.service` and `openbao-agent.service` when the
  Agent service is expected.
- WHERE `openbao_vector_enabled=true` THE SYSTEM SHALL tag forwarded events
  with at least cluster name, inventory hostname, log type, and source service
  or file.
- WHERE `openbao_vector_enabled=true` THE SYSTEM SHALL send events to
  `openbao_vector_opensearch_endpoints` with a stable OpenSearch-compatible
  sink configuration.

### Story 3: Credentials from OpenBao

As an operator, I want Vector's OpenSearch credentials to come from OpenBao
itself, so that static OpenSearch credentials are not committed, exposed as CI
artifacts, or embedded in Vector config.

Acceptance criteria:

- WHERE Vector OpenBao secret rendering is enabled THE SYSTEM SHALL configure a
  per-node AppRole and policy for OpenBao Agent.
- WHERE Vector OpenBao secret rendering is enabled THE SYSTEM SHALL grant the
  Agent policy only the minimum read capability needed for the selected KV v2
  data path, plus any listener certificate capability required by certificate
  renewal mode.
- WHERE Vector OpenBao secret rendering is enabled THE SYSTEM SHALL render
  OpenSearch credentials into local files under a managed Vector secret
  directory with restrictive permissions.
- WHERE Vector OpenBao secret rendering is enabled THE SYSTEM SHALL configure
  Vector to reference rendered files through `SECRET[...]` references rather
  than plaintext config values.
- IF the selected OpenBao secret is missing or lacks required fields THEN THE
  SYSTEM SHALL fail with a clear message before claiming Vector is healthy.

### Story 4: Agent without forced certificate renewal

As an operator, I want Vector secret rendering to work in bootstrap certificate
mode, so that logging can be enabled without immediately switching listener
certificate renewal to OpenBao Agent.

Acceptance criteria:

- WHERE `openbao_certificate_mode=bootstrap` and `openbao_vector_enabled=true`
  THE SYSTEM SHALL allow OpenBao Agent to run for Vector secret rendering
  without issuing listener certificates.
- WHERE `openbao_certificate_mode=agent` and `openbao_vector_enabled=true` THE
  SYSTEM SHALL preserve the existing listener certificate renewal behavior and
  add Vector secret rendering to the same Agent service.
- WHERE OpenBao Agent is enabled only for Vector THE SYSTEM SHALL skip listener
  certificate bundle waits, listener certificate hook execution, and listener
  certificate name validation.

### Story 5: Validation and operations

As an operator, I want predictable validation and documentation, so that I can
turn the feature on, replace a lab cluster, and understand what is deleted or
preserved.

Acceptance criteria:

- THE SYSTEM SHALL document every new operator-facing variable in
  `docs/variables.md`.
- THE SYSTEM SHALL add README guidance showing how to store the OpenSearch
  secret in OpenBao and enable Vector.
- WHEN `openbao_replace_existing=true` THE SYSTEM SHALL stop Vector if present
  and remove managed Vector config, rendered secrets, and Vector state while
  preserving external operator inputs and installed packages.
- THE SYSTEM SHALL validate generated Vector configuration with
  `vector validate` before starting or restarting Vector.
- THE SYSTEM SHALL include lab validation for first enablement, repeated
  replacement with secret seeding, and OpenSearch ingestion when Docker is
  available.

## Non-Functional Requirements

- Secrets must use `no_log: true` for Ansible tasks that read, write, or render
  credential material.
- Rendered credential files must be readable by the Vector service user and not
  world-readable.
- Vector must not need root filesystem read bypass capabilities for
  `/var/log/openbao/audit.log`; use group membership or ACLs instead.
- Vector state should live in a managed data directory and survive normal
  reruns, but be removed by replacement.
- The implementation must pass the repository's static Ansible validation
  commands.

## Open Questions

- Should AWS OpenSearch authentication be included in the first implementation
  or deferred behind a later `openbao_vector_opensearch_auth_strategy=aws`
  extension?
- Should production deployments expect the Vector YUM repository to be managed
  outside this role, or should the role gain an explicit
  `openbao_vector_manage_yum_repo` path in the first implementation?
- Should normal logs include only `openbao.service` and `openbao-agent.service`,
  or should HAProxy/load-balancer logs in the lab also be modeled as an
  optional source?

