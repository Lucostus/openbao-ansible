---
inclusion: always
generatedBy: specops
updated: 2026-07-30T12:02:49Z
---

# Dependency Steering

Detected dependency surfaces:

- Ansible Galaxy collections: `requirements.yml`.
- RHEL RPM packages installed by Ansible roles.
- OpenBao release RPMs downloaded from GitHub and installed from the local
  package cache.
- Python and shell helper scripts used by Ansible tasks and the lab.

Dependency policy:

- Do not add language package dependencies unless a spec explicitly approves
  them.
- Prefer OS packages already present in enabled repositories.
- Third-party package repositories must be configured declaratively when
  practical and documented as operator-visible supply chain inputs.
- Downloaded binaries or RPMs need a clear provenance and, when supported by
  the upstream source, checksum or GPG verification.

Current approved net-new dependencies for draft specs:

- `vector` OS package, approved only for
  `2026-07-30-openbao-vector-opensearch-logging` subject to the design's
  installation constraints.

