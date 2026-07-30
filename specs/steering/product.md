---
inclusion: always
generatedBy: specops
updated: 2026-07-30T12:02:49Z
---

# Product Steering

This repository deploys and maintains OpenBao high-availability clusters on
RHEL-family hosts. The operator-facing product is an Ansible workflow for
standing up three-node OpenBao clusters with integrated Raft storage, TLS,
static seal material, audit logging, and later certificate renewal.

The primary users are platform operators who run `playbooks/site.yml` and
`playbooks/upgrade.yml` against selected inventory groups such as `rhel10`,
`openbao-prod`, and `openbao-test`.

Default behavior should stay conservative: bootstrap listener TLS first, no
OpenBao Agent service by default, no untracked secrets, and clear failure
messages when operator inputs are incomplete or drifted.

