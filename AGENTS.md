# Agent Instructions For This Repository

## Mission

Continue work until the OpenBao HA Ansible plan in
`OPENBAO_ORIGINAL_PLAN.md` is fully implemented, validated, and ready for an
operator to run against the three RHEL hosts.

Do not stop at analysis when implementation or verification work remains.
Make the smallest safe changes needed to close gaps against the plan, then run
the relevant validation commands.

## Current Project Shape

This repository is scoped to the OpenBao Ansible project. Previous
GitOps/Kustomize source trees were removed at the user's request.

Important Ansible entry points:

- `playbooks/site.yml`: initial OpenBao HA deployment at `openbao_version`.
- `playbooks/upgrade.yml`: rolling upgrade to the desired `openbao_version`.
- `group_vars/rhel10/main.yml`: non-secret defaults.
- `group_vars/rhel10/vault.yml.example`: required secret variable shape.
- `README-openbao-ansible.md`: operator-facing usage notes.
- `OPENBAO_ORIGINAL_PLAN.md`: source plan and acceptance criteria.

## Git And Ignore Rules

The repository uses a deny-by-default `.gitignore`. If adding new project files,
also add explicit allow rules so they are tracked.

Never commit generated or sensitive files:

- `secure-artifacts/`
- `.ansible/`
- `group_vars/**/vault.yml`
- real private keys or certificates under `files/bootstrap-tls/`

Only placeholders, examples, and documentation should be tracked for secrets or
certificates.

## Implementation Expectations

Preserve these design decisions unless the user changes them:

- Three RHEL hosts in group `rhel10`.
- OpenBao desired version is controlled only by `openbao_version`.
- Integrated Raft storage.
- TCP passthrough load balancer model by default.
- Static auto-unseal using a 32-byte vaulted key.
- Bootstrap TLS files supplied by the operator. Default `agent_pki`
  deployments read first-run cert/key material from each VM under the
  configured remote cockpit cert path, while controller files under
  `files/bootstrap-tls/` remain the lab and fallback source.
- OpenBao PKI intermediate signed with vaulted root CA material.
- Certificate renewal default: per-node OpenBao Agent PKI issuance with
  OpenBao-managed AppRole credentials.
- Native listener ACME remains available with `eab_policy=always-required`,
  a shared NFS CertMagic cache, and `tls-alpn-01` when explicitly selected.
- ACME challenge must remain configurable across `http-01` and `tls-alpn-01`.
- Role-qualified EAB tokens must be generated from
  `pki_openbao/roles/openbao-listener/acme/new-eab` because EAB tokens are tied
  to a specific ACME directory.

Keep the Ansible design idempotent and declarative:

- Prefer modules that converge state (`dnf`, `template`, `copy`, `file`,
  `systemd_service`, `firewalld`, `sefcontext`) over imperative shell logic.
- Commands must have explicit `changed_when`/`failed_when`, guards, or
  controller-side artifacts so repeated runs do not reinitialize the cluster,
  regenerate secrets, or restart services unnecessarily.
- Variables describe desired state. Avoid hidden sequencing assumptions that
  require manual cleanup between runs.
- Never make a task pass by ignoring drift; either converge the drift or fail
  with a clear preflight or validation message.

Do not reintroduce external ACME clients unless the user explicitly asks.

## Validation Checklist

Run these after changing Ansible files:

```bash
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/upgrade.yml
ansible-inventory --graph
```

Run these if available in the environment:

```bash
ansible-lint
yamllint .
```

If a validator is missing, state that clearly in the final answer. Do not claim
it passed.

## Production Readiness Gaps To Keep Closing

When continuing this work, check the implementation against these plan items:

- Preflight gives clear failures for missing bootstrap TLS files from the
  selected source, partial listener cert/key pairs, invalid static seal key
  length, missing vaulted root CA material, and impossible ACME challenge
  selections.
- RPM downloads verify against the same release checksum file.
- OpenBao config validates before restart.
- Init output, per-node OpenBao Agent AppRole artifacts, and reusable EAB
  artifacts are stored under `secure-artifacts/` on the controller; listener
  ACME EAB values are rendered into root-owned OpenBao config with restrictive
  permissions only when listener ACME is active.
- PKI ACME response headers include `Replay-Nonce`, `Link`, `Location`, and
  `Last-Modified`.
- The upgrade playbook snapshots Raft before changing any node.
- Standby nodes upgrade before the active node.
- Final upgrade validation confirms unsealed state and desired `openbao_version`.

## Operator Inputs That Must Remain External

Do not invent real production values. Keep these as variables or examples:

- Real node FQDNs.
- Real public or load balancer FQDN.
- Root CA certificate and private key.
- Static unseal key.
- Shared NFS export for listener ACME cache when `openbao_tls_mode` is
  `listener_acme`.
- First-run bootstrap certificates and keys, usually already present on each
  node under `/usr/local/lib/cockpitcert/` for `agent_pki`.
- Load balancer configuration.

## Final Response Style

When reporting work, be concise and specific:

- Name changed files.
- Name validations run.
- Mention validators that were unavailable.
- Mention any remaining operator inputs or risks.
