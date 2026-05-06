# OpenBao HA Ansible Deployment

This repository deploys three-node OpenBao HA clusters on RHEL with integrated
Raft storage, TLS, static auto-unseal, and audit logging.

Bootstrap listener TLS is the default fresh production path. OpenBao Agent
renewal can be enabled later by changing one variable. Native listener ACME is
retained as an advanced fallback and documented separately.

## Bootstrap First, Agent Later

The default deployment starts without OpenBao Agent and keeps using the
supplied listener certificates:

```yaml
openbao_certificate_mode: bootstrap
openbao_bootstrap_tls_source: node
openbao_node_bootstrap_tls_dir: /usr/local/lib/cockpitcert
```

This deploys OpenBao HA and leaves the listener on the bootstrap cert/key pair
without requiring Ansible Vault, configuring OpenBao PKI, or installing
`openbao-agent`.

Later, enable Agent renewal by changing only:

```yaml
openbao_certificate_mode: agent
```

Before enabling Agent renewal, add a PKI signing source such as
`openbao_root_ca_cert_pem` and `openbao_root_ca_key_pem` in an encrypted
environment vault. Then rerun:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

The rerun does not reinitialize OpenBao. It reuses the existing PKI, creates
missing Agent AppRole artifacts, starts `openbao-agent`, and replaces the
bootstrap listener certificates with Agent-issued certificates.

## Configure

The default lab-style inventory still targets `rhel10`. For production and
test from one repo, use `inventory/openbao.yml` and select one environment per
run with `openbao_target_group`.

Edit the environment input file:

```yaml
# group_vars/openbao-prod/main.yml
openbao_version: "2.5.3"
openbao_public_fqdn: bao-prod.example.at

openbao_certificate_mode: bootstrap
openbao_bootstrap_tls_source: node
openbao_node_bootstrap_tls_dir: /usr/local/lib/cockpitcert
openbao_manage_hosts_entries: false
openbao_tls_trust_source: system
```

DNS-only prod/test inventories use each host's `ansible_host` as the OpenBao
node FQDN:

```yaml
openbao-prod:
  hosts:
    aspsecret1:
      ansible_host: lagaspsecret1.example.at
```

No vault file is required for bootstrap mode. A static seal key is generated
once per environment under ignored `secure-artifacts/<group>/` and copied to
the selected nodes. Existing matching node seal keys are adopted; mismatches
fail rather than being overwritten.

Create and encrypt a secret file only when enabling Agent or native ACME
certificate renewal:

```bash
cp group_vars/rhel10/vault.yml.example group_vars/openbao-prod/vault.yml
ansible-vault encrypt group_vars/openbao-prod/vault.yml
```

Vaulted PKI values for renewal modes:

- `openbao_root_ca_cert_pem`: root CA certificate.
- `openbao_root_ca_key_pem`: root CA key for signing the OpenBao intermediate.

By default, first-run listener cert/key material is expected on each node under
`/usr/local/lib/cockpitcert` for both `agent` and `bootstrap` modes. Ansible
copies it locally on the node into `/etc/openbao.d/tls`; private keys are not
copied back to the controller.

## Deploy

Install collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

Deploy production:

```bash
ansible-playbook -i inventory/openbao.yml playbooks/site.yml \
  -e openbao_target_group=openbao-prod
```

Deploy test:

```bash
ansible-playbook -i inventory/openbao.yml playbooks/site.yml \
  -e openbao_target_group=openbao-test
```

Generated init output is stored under `secure-artifacts/` on the controller.
Per-node OpenBao Agent AppRole artifacts are created there only when
`openbao_certificate_mode` is `agent`.

## Upgrade

Change only `openbao_version`, then run:

```bash
ansible-playbook -i inventory/openbao.yml playbooks/upgrade.yml \
  -e openbao_target_group=openbao-prod
```

The upgrade playbook rejects downgrades, validates Raft membership, snapshots
Raft before package changes, upgrades standby nodes before the active node, and
validates the desired version.

## Validate

```bash
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/upgrade.yml
ansible-inventory --graph
ansible-lint
yamllint .
```

## More

- Full variable reference: `docs/variables.md`
- Native listener ACME fallback: `docs/native-listener-acme.md`
- Upgrade details: `docs/upgrade.md`
- Docker lab: `lab/README.md`
