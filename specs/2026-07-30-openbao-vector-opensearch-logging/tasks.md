# Tasks

## Task 1: Defaults And Validation

**Status:** Completed
**Priority:** High
**IssueID:** None

**Description:** Add the Vector variable surface and validate it early.

**Implementation Steps:**

1. Add all `openbao_vector_*` defaults to
   `group_vars/all/openbao_defaults.yml`.
2. Refactor Agent enablement defaults into service enablement and listener
   certificate renewal booleans.
3. Add preflight assertions for required Vector settings when
   `openbao_vector_enabled=true`.
4. Assert OpenSearch endpoints are non-empty absolute HTTP(S) URLs.
5. Assert the OpenBao KV mount/path/field settings are non-empty and do not
   contain unsafe path traversal.
6. Ensure new variables pass known-variable validation.

**Acceptance Criteria:**

- [x] `openbao_vector_enabled=false` keeps current behavior unchanged.
- [x] Invalid Vector settings fail before package or service changes.
- [x] Bootstrap certificate mode plus Vector no longer fails solely because
  OpenBao Agent is enabled for non-certificate templates.

## Task 2: Reusable OpenBao Agent Identity

**Status:** Completed
**Priority:** High
**IssueID:** None

**Description:** Move per-node OpenBao Agent AppRole creation out of the PKI
role so it can serve both listener certificate renewal and Vector secret
rendering.

**Implementation Steps:**

1. Extract the common AppRole identity flow from
   `roles/openbao_pki/tasks/configure_agent_identity.yml`.
2. Build policy text from selected capability fragments.
3. Keep the existing PKI issue policy fragment when
   `openbao_agent_listener_cert_enabled=true`.
4. Add the KV v2 read policy fragment when
   `openbao_agent_vector_secret_enabled=true`.
5. Include policy shape and Vector secret coordinates in the artifact currency
   fingerprint.
6. Wire identity creation after OpenBao bootstrap and before Agent convergence.

**Acceptance Criteria:**

- [x] Agent AppRole artifacts are created for Vector-only Agent use.
- [x] Existing listener certificate renewal AppRole behavior is preserved.
- [x] A stale artifact is regenerated when policy fragments or Vector secret
  coordinates change.

## Task 3: OpenBao Agent Template Refactor

**Status:** Completed
**Priority:** High
**IssueID:** None

**Description:** Generalize `roles/openbao_agent` so one Agent service can
render listener certificates, Vector secrets, or both.

**Implementation Steps:**

1. Rename service description and messages away from certificate-only wording.
2. Render listener certificate template and hook only when
   `openbao_agent_listener_cert_enabled=true`.
3. Render Vector secret templates when
   `openbao_agent_vector_secret_enabled=true`.
4. Add a Vector secret hook that validates non-empty secret files and restarts
   Vector when safe.
5. Update the Agent systemd hardening `ReadWritePaths` for Vector secret
   output.
6. Conditionalize listener certificate waits and validations.
7. Update final site validation messages for Agent-enabled features.

**Acceptance Criteria:**

- [x] Vector-only Agent mode starts without listener certificate bundle waits.
- [x] Certificate-renewal Agent mode still validates listener cert names.
- [x] Agent renders OpenSearch username/password files with restrictive
  permissions.

## Task 4: Vector Role

**Status:** Completed
**Priority:** High
**IssueID:** None

**Description:** Add `roles/openbao_vector` to install, configure, validate,
and start Vector.

**Implementation Steps:**

1. Create role directories, handlers, tasks, and templates.
2. Install the `vector` OS package with `dnf`.
3. Ensure Vector directories and secret directory permissions.
4. Add the Vector user to `openbao_service_group` for audit log access.
5. Add the Vector user to `systemd-journal` when the group exists.
6. Render `/etc/vector/vector.yaml` from enabled sources/transforms/sink vars.
7. Wait for required rendered secret files.
8. Run `vector validate` with health checks skipped by default.
9. Enable and start `vector.service`.

**Acceptance Criteria:**

- [x] Vector can read `/var/log/openbao/audit.log` without running as root.
- [x] Vector config contains `SECRET[...]` references instead of plaintext
  credentials.
- [x] Vector service starts only after required secret files exist.

## Task 5: Playbook And Replacement Wiring

**Status:** Completed
**Priority:** Medium
**IssueID:** None

**Description:** Wire Vector into `site.yml` and replacement cleanup.

**Implementation Steps:**

1. Add the Agent identity role/tasks to `playbooks/site.yml`.
2. Add the Vector role to `playbooks/site.yml` after Agent convergence.
3. Keep `upgrade.yml` focused on OpenBao upgrades; adjust Agent restart logic
   only if the Agent enablement refactor requires it.
4. Extend `replace_existing.yml` to stop Vector and remove managed Vector
   config, secret, and state paths.
5. Ensure replacement preserves the installed Vector package and external
   operator inputs.

**Acceptance Criteria:**

- [x] `site.yml` converges OpenBao plus Vector when enabled.
- [x] `upgrade.yml` remains a rolling OpenBao upgrade path, not a Vector
  configuration entry point.
- [x] Replacement removes managed Vector runtime state and leaves packages
  installed.

## Task 6: Optional Secret Seeding

**Status:** Completed
**Priority:** Medium
**IssueID:** None

**Description:** Support repeatable lab/replacement runs by optionally writing
the OpenSearch credential secret into OpenBao from vaulted values.

**Implementation Steps:**

1. Add validation for `openbao_vector_seed_opensearch_secret=true`.
2. Require `openbao_vector_opensearch_secret_data` to include the configured
   username/password fields when seeding is enabled.
3. Use `bao kv put` or equivalent API calls with `no_log: true`.
4. Keep seeding disabled by default.
5. Document that production operators can instead pre-create the secret.

**Acceptance Criteria:**

- [x] Missing secret data fails clearly when seeding is requested.
- [x] Secret values never appear in Ansible output.
- [x] Replacement plus seeding can recreate a working lab pipeline.

## Task 7: Documentation

**Status:** Completed
**Priority:** Medium
**IssueID:** None

**Description:** Document the feature and its security/operations model.

**Implementation Steps:**

1. Add README enablement guidance.
2. Add `docs/variables.md` entries for new variables.
3. Add lab README steps for OpenSearch, secret seeding, and validation.
4. Document package repository prerequisites.
5. Document replacement effects on Vector and the OpenBao KV secret.

**Acceptance Criteria:**

- [x] Operators can follow README steps to enable Vector.
- [x] Variable docs identify defaults, required values, and secret handling.
- [x] Replacement docs explain that OpenBao-stored Vector credentials are
  deleted when the cluster is recreated.

## Task 8: Lab And Static Validation

**Status:** Completed
**Priority:** High
**IssueID:** None

**Description:** Prove default behavior, Vector enablement, replacement, and
OpenSearch ingestion.

**Implementation Steps:**

1. Extend lab compose with an OpenSearch-compatible target when practical.
2. Add lab vars for Vector enablement and secret seeding.
3. Run the repository static validation commands.
4. Run lab default site and upgrade paths.
5. Run lab Vector enablement and ingestion checks.
6. Run repeated replacement with Vector secret seeding.

**Acceptance Criteria:**

- [x] Static validation passes.
- [x] Default lab behavior still passes with Vector disabled.
- [x] Vector-enabled lab run forwards audit and service events to OpenSearch.
- [x] Repeated replacement with Vector enabled and seeded secrets finishes
  healthy.
