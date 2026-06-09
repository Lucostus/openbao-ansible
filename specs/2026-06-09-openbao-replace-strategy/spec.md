# Spec: OpenBao Replace Existing Strategy

**Status:** Complete
**Created:** 2026-06-09
**Research:** [research.md](./research.md)

---

## Overview

Add a destructive, group-var-controlled replacement path to `site.yml`.

**Current state:** The repository can converge or upgrade OpenBao, but has no
production reset/replace strategy. Deleting controller artifacts alone does not
reinitialize the cluster because remote Raft and seal state remain.

**Target state:** Operators can set `openbao_replace_existing: true` and run
`playbooks/site.yml`; the playbook removes Ansible-managed OpenBao state and
artifacts, preserves externally uploaded TLS/CA inputs, then recreates the
cluster from scratch. `playbooks/upgrade.yml` refuses to run with replacement
enabled.

---

## Public Interface

Add one operator-facing variable:

```yaml
openbao_replace_existing: false
```

Behavior:

- Default `false`: current convergent behavior is unchanged.
- `true`: `site.yml` destroys and recreates the selected OpenBao deployment
  every run.
- No extra confirmation variable.
- `upgrade.yml` fails early with a clear message if this variable is true.

---

## Definitions

Managed footprint:
OpenBao files/directories Ansible creates or owns, including config, data,
Raft, seal key, installed listener TLS copies, logs, package cache, systemd
units, Agent config/state, generated node-subCA bootstrap output, and generated
controller artifacts.

External operator inputs:
Inventory, `group_vars`, vaulted vars, uploaded bootstrap TLS source files,
uploaded node sub-CA cert/key material, issuer directories, and
`files/bootstrap-tls/`.

OS basics:
Installed packages, service user/group, firewalld rules, and SELinux port
rules. These remain installed/configured.

Controller artifacts:
The selected `openbao_secure_artifacts_dir`; replacement deletes this entire
directory, including init JSON, static seal key artifact, Agent AppRole
artifacts, generated self-signed certs, and snapshots.

---

## Scope

### In Scope

- Add `openbao_replace_existing` to `group_vars/all/openbao_defaults.yml`.
- Add `roles/openbao_common/tasks/replace_existing.yml`.
- Wire replacement into `playbooks/site.yml` after target/SSH validation and
  before normal OpenBao convergence.
- Add early `upgrade.yml` refusal when replacement is enabled.
- Preserve uploaded TLS/CA inputs.
- Delete the selected controller artifact directory.
- Document behavior and risks.

### Out of Scope

- No rollback automation.
- No package uninstall.
- No removal of service user/group.
- No removal of firewalld or SELinux rules.
- No attempt to preserve OpenBao data, root token, snapshots, PKI mounts, Agent
  identities, or Raft state.

---

## Steps

### Step 1: Add Defaults And Known Variable Support

**Action:** Add `openbao_replace_existing: false` to
`group_vars/all/openbao_defaults.yml`.

**Files:**
- `group_vars/all/openbao_defaults.yml`

**Verification:**
- [x] Variable exists and defaults to `false`.
- [x] Existing known-var validation allows it through defaults.

---

### Step 2: Add Replacement Task File

**Action:** Create `roles/openbao_common/tasks/replace_existing.yml`.

**Files:**
- `roles/openbao_common/tasks/replace_existing.yml`

**Changes:**
- Assert `openbao_secure_artifacts_dir` is non-empty and not an unsafe path such
  as `/`, repo root, `/etc`, `/var`, `/usr`, or `/tmp`.
- Delete `openbao_secure_artifacts_dir` on localhost with
  `delegate_to: localhost`, `run_once: true`.
- Gather service facts.
- Stop and disable `openbao-agent` if present.
- Stop and disable `openbao` if present.
- Remove managed systemd files:
  - `/etc/systemd/system/openbao.service`
  - `/etc/systemd/system/openbao.service.d`
  - `/etc/systemd/system/openbao-agent.service`
- Reload systemd.
- Remove managed remote paths/files, including configured OpenBao config/data/log
  cache dirs, Agent config/state dirs, installed TLS/seal files, audit log,
  Agent hook, Agent bundle, and generated node-subCA chain output only when
  Ansible builds it.
- Explicitly do not delete uploaded bootstrap TLS source dirs/files or uploaded
  sub-CA cert/key/issuer inputs.

**Verification:**
- [x] Task file exists.
- [x] Commands/tasks have idempotent module behavior or explicit change
      behavior.
- [x] Uploaded TLS/CA source paths are not deleted by the task.

---

### Step 3: Wire Replacement Into site.yml

**Action:** Add a play named `Replace existing OpenBao deployment when
requested`.

**Files:**
- `playbooks/site.yml`

**Changes:**
- Target `{{ openbao_target_group | default('rhel10') }}`.
- Use `become: true`, `gather_facts: false`, `any_errors_fatal: true`.
- Load OpenBao vars with `load_openbao_vars.yml`.
- Import/include `replace_existing.yml` only when `openbao_replace_existing |
  bool`.

**Verification:**
- [x] Play appears after target/SSH validation and before normal OpenBao
      convergence.
- [x] Replacement task is gated by `openbao_replace_existing | bool`.

---

### Step 4: Guard upgrade.yml

**Action:** Add an early assertion after variables are loaded near the beginning
of upgrade validation.

**Files:**
- `playbooks/upgrade.yml`

**Changes:**
- Assert `not (openbao_replace_existing | bool)`.
- Failure message says replacement is only supported through `playbooks/site.yml`.

**Verification:**
- [x] `upgrade.yml` fails before upgrade classification when replacement is
      enabled.

---

### Step 5: Document Behavior

**Action:** Document replacement in README and variable docs.

**Files:**
- `README.md`
- `docs/variables.md`

**Changes:**
- Show:
  ```yaml
  openbao_replace_existing: true
  ```
  followed by a `playbooks/site.yml` command.
- State that every run while true wipes and recreates the cluster.
- State exactly what is preserved and what is deleted.

**Verification:**
- [x] README contains operator-facing replacement instructions.
- [x] Variable docs list and explain `openbao_replace_existing`.

---

## Verification Checklist

- [x] `ansible-playbook --syntax-check playbooks/site.yml`
- [x] `ansible-playbook --syntax-check playbooks/upgrade.yml`
- [x] `ansible-inventory --graph`
- [x] `ansible-lint`
- [x] `yamllint .`
- [x] Lab: `lab/scripts/openbao-lab-generate-inputs.sh`
- [x] Lab: `docker compose -f lab/compose.yml up -d --build`
- [x] Lab: `lab/scripts/openbao-lab-playbook.sh site`
- [x] Lab: `lab/scripts/openbao-lab-playbook.sh site -e openbao_replace_existing=true`
- [x] Lab repeated replacement:
      `lab/scripts/openbao-lab-playbook.sh site -e openbao_replace_existing=true`
- [x] Lab upgrade guard:
      `lab/scripts/openbao-lab-playbook.sh upgrade -e openbao_replace_existing=true`
- [x] Lab health check:
      `curl --resolve bao.lab.local:8443:127.0.0.1 --cacert secure-artifacts/lab/ca/root-ca.pem https://bao.lab.local:8443/v1/sys/health`

---

## Execution Plan

**Mode:** Subagents
**Rationale:** The user requested three parallel subagents.

### Parallel

- Implementation agent: Steps 1-4.
- Docs agent: Step 5.
- Test/lab agent: Inspect validation commands and execute the verification
  checklist after implementation is integrated.

**Max concurrent:** 3

### Final Reconciliation

One final pass reconciles subagent changes, runs validation, and performs
review against this spec.
