---
inclusion: always
generatedBy: specops
updated: 2026-07-30T12:02:49Z
---

# Technical Steering

The repo is an Ansible project for RHEL-family systemd hosts. It uses:

- Ansible playbooks in `playbooks/`
- reusable roles in `roles/`
- environment variables in `group_vars/<target>/main.yml`
- low-level defaults in `group_vars/all/openbao_defaults.yml`
- ignored controller artifacts under `secure-artifacts/`
- a Docker lab under `lab/`

Implementation should prefer declarative Ansible modules. Shell or command
tasks need explicit `changed_when`, `failed_when`, retries, or idempotent
artifact checks.

OpenBao is installed from pinned release RPMs with checksum verification.
New operating system packages or third-party repositories require explicit
documentation, validation, and a dependency decision in the relevant spec.

