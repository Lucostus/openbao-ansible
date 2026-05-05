# OpenBao HA Ansible Deployment

This repository deploys a three-node OpenBao HA cluster on RHEL with integrated
Raft storage, TLS, static auto-unseal, audit logging, and an OpenBao-managed
PKI intermediate.

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

This deploys OpenBao HA, configures PKI, and leaves the listener on the
bootstrap cert/key pair without installing or starting `openbao-agent`.

Later, enable Agent renewal by changing only:

```yaml
openbao_certificate_mode: agent
```

Then rerun:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

The rerun does not reinitialize OpenBao. It reuses the existing PKI, creates
missing Agent AppRole artifacts, starts `openbao-agent`, and replaces the
bootstrap listener certificates with Agent-issued certificates.

## Configure

Edit the small site input file:

```yaml
# group_vars/rhel10/main.yml
openbao_version: "2.5.3"
openbao_public_fqdn: bao.example.com

openbao_nodes:
  rhel10-ansible-1:
    fqdn: bao1.example.com
    ip: 10.0.0.11
```

Create and encrypt the secret file:

```bash
cp group_vars/rhel10/vault.yml.example group_vars/rhel10/vault.yml
ansible-vault encrypt group_vars/rhel10/vault.yml
```

Required vaulted values:

- `openbao_static_unseal_key_b64`: base64 for exactly 32 raw bytes.
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

Deploy the cluster:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Generated init output is stored under `secure-artifacts/` on the controller.
Per-node OpenBao Agent AppRole artifacts are created there only when
`openbao_certificate_mode` is `agent`.

## Upgrade

Change only `openbao_version`, then run:

```bash
ansible-playbook playbooks/upgrade.yml --ask-vault-pass
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
