# Dependency Audit

## Summary

Dependency safety status for the draft spec: Pass with noted operator supply
chain prerequisites.

The feature introduces one new operating system package dependency, `vector`.
No new Ansible Galaxy collection, Python package, JavaScript package, Go module,
or container base image dependency is required by the initial design.

## Detected Ecosystems

- Ansible Galaxy: `requirements.yml`
- RHEL RPM packages installed by Ansible
- Docker lab images and services under `lab/`
- Shell/Python helper scripts with standard library usage

No lockfile-based language package ecosystems were detected.

## Net-New Dependency Review

### `vector` OS package

Decision: Approved.

Reasoning:

- Vector provides production-grade file tailing, journald ingestion,
  checkpointing, batching, backpressure, TLS, secret references, VRL transforms,
  and OpenSearch-compatible bulk delivery.
- Building this behavior directly in Ansible, shell, or a custom daemon would
  be fragile and less maintainable.
- The package is optional and disabled by default through
  `openbao_vector_enabled=false`.

Controls:

- Install with `dnf` from an operator-managed repository or local mirror.
- Do not run `curl | bash` setup scripts from Ansible.
- Do not store OpenSearch credentials in package manager config, Vector config,
  git, or GitLab artifacts.
- Validate generated config with `vector validate`.

Residual risk:

- Operators need an approved source for the Vector RPM repository or local
  mirror. The role should document this clearly and fail cleanly if the package
  is unavailable.

## Vulnerability Scan

No automated vulnerability scan was run because implementation has not started
and no package lock or concrete installed Vector package version exists in the
repo yet. During implementation, validation should record the installed Vector
version in lab output where available.

