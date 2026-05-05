# Agent Instructions

## Mission

Maintain this OpenBao HA Ansible repository so it stays clear, idempotent, and
ready for operators to run against the three RHEL hosts in group `rhel10`.

## Defaults

- Default fresh deployment: `openbao_certificate_mode=bootstrap`, using the
  provided listener cert/key and no OpenBao Agent service.
- Later certificate renewal: switch to `openbao_certificate_mode=agent` and
  rerun `playbooks/site.yml`.
- Advanced fallback: native OpenBao listener ACME.
- Operator inputs live in `group_vars/rhel10/main.yml`.
- Low-level defaults live in `group_vars/all/openbao_defaults.yml`.
- Secrets live only in `group_vars/rhel10/vault.yml` or ignored generated paths.

## Do Not Track

Never commit:

- `secure-artifacts/`
- `.ansible/`
- `group_vars/**/vault.yml`
- real private keys or production certificates under `files/bootstrap-tls/`

Only placeholders, examples, and docs should be tracked for secret material.

## Implementation Rules

- Preserve the three-node RHEL HA model with integrated Raft and static seal.
- Keep `openbao_version` as the only desired-version input.
- Keep the default deployment free of native ACME requirements.
- Use declarative Ansible modules where practical.
- Commands must have explicit `changed_when`, `failed_when`, guards, or
  idempotent artifact checks.
- Do not ignore drift; converge it or fail with a clear message.

## Validation

Run after Ansible changes:

```bash
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/upgrade.yml
ansible-inventory --graph
ansible-lint
yamllint .
```

Run the Docker lab before final handoff when Docker is available:

```bash
lab/scripts/openbao-lab-generate-inputs.sh
docker compose -f lab/compose.yml up -d --build
lab/scripts/openbao-lab-playbook.sh site
lab/scripts/openbao-lab-playbook.sh upgrade
curl --resolve bao.lab.local:8443:127.0.0.1 \
  --cacert secure-artifacts/lab/ca/root-ca.pem \
  https://bao.lab.local:8443/v1/sys/health
```

## Final Response

Report changed files, validation commands run, unavailable validators if any,
lab result, and remaining operator inputs or risks.
