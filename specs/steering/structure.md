---
inclusion: always
generatedBy: specops
updated: 2026-07-30T12:02:49Z
---

# Structure Steering

Key project paths:

- `playbooks/site.yml`: primary convergence entry point.
- `playbooks/upgrade.yml`: rolling OpenBao upgrade entry point.
- `roles/openbao_common/`: shared validation, system setup, TLS, seal,
  replacement, and helper tasks.
- `roles/openbao_server/`: OpenBao server configuration and systemd unit.
- `roles/openbao_bootstrap/`: initialization and Raft bootstrap handling.
- `roles/openbao_pki/`: OpenBao PKI setup and current Agent AppRole identity
  creation for listener certificate renewal.
- `roles/openbao_agent/`: OpenBao Agent installation, templating, and listener
  certificate hook.
- `docs/`: operator documentation.
- `lab/`: Docker-backed validation environment.

Feature specs should list affected files concretely and keep future tasks
within these ownership boundaries.

