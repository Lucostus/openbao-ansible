# OpenBao HA Ansible Deployment

This repository deploys three-node OpenBao HA clusters on RHEL with integrated
Raft storage, TLS, static auto-unseal, and audit logging.

Bootstrap listener TLS is the default fresh production path. OpenBao Agent
renewal can be enabled later by changing one variable. Native listener ACME is
retained as an advanced fallback and documented separately.

## Bootstrap First, Agent Later

The default deployment starts without OpenBao Agent and uses per-node listener
certificates when they exist. If no real listener cert/key pair is present yet,
Ansible generates a temporary bootstrap CA and per-node listener certificates
under ignored `secure-artifacts/` so the cluster can start with TLS verification
still enabled:

```yaml
openbao_certificate_mode: bootstrap
openbao_bootstrap_tls_source: node
openbao_node_bootstrap_tls_dir: /usr/local/lib/cockpitcert
openbao_bootstrap_tls_missing_strategy: generate_self_signed
```

This deploys OpenBao HA and leaves the listener on the selected bootstrap
cert/key pair without requiring Ansible Vault, configuring OpenBao PKI, or
installing `openbao-agent`.

Later, enable Agent renewal by changing only:

```yaml
openbao_certificate_mode: agent
```

Before enabling Agent renewal, add a PKI signing source. The default signing
source is `openbao_root_ca_cert_pem` and `openbao_root_ca_key_pem` in an
encrypted environment vault. Environments with a subordinate CA already on one
or all OpenBao nodes can instead use `openbao_pki_signing_source=node_subca`.
Then rerun. Use `--ask-vault-pass` only when encrypted vault variables are
needed:

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
`/usr/local/lib/cockpitcert` for both `agent` and `bootstrap` modes. Use one
pair per host, preferably named after the inventory host:
`<inventory_hostname>.fullchain.pem` and `<inventory_hostname>.key.pem`.
FQDN-based names are also auto-detected. Ansible copies the selected files
locally on the node into `/etc/openbao.d/tls`; private keys are not copied back
to the controller.

If a node has neither real file and
`openbao_bootstrap_tls_missing_strategy=generate_self_signed`, Ansible generates
a shared temporary bootstrap CA plus one leaf certificate per node under
`secure-artifacts/<group>/bootstrap-selfsigned/`. These generated certs are only
for first deployment. After the real cert/key files are placed at the per-node
paths, rerun `playbooks/site.yml`; the playbook replaces the generated listener
certs and validates against the configured trust source again. A partial real
pair, such as a cert without its key, fails instead of falling back.

If one node, or every node, has a subordinate CA at `/etc/openbao-subca/`, use
node-subCA bootstrap and PKI signing:

```yaml
openbao_certificate_mode: agent
openbao_bootstrap_tls_source: node
openbao_bootstrap_tls_missing_strategy: issue_from_node_subca
openbao_bootstrap_tls_replace_existing: true
openbao_pki_signing_source: node_subca
openbao_node_subca_topology: auto
openbao_node_bootstrap_tls_autodetect: false
openbao_node_subca_chain_file: /etc/openbao-subca/subca-chain.pem
```

With one complete sub-CA host, that host signs bootstrap CSRs for the cluster.
With complete sub-CA material on all three hosts, each node signs locally.
Private sub-CA keys are never copied to the controller or to other nodes. Use a
chain file containing the sub-CA and its issuer chain when the sub-CA is not a
self-signed trust anchor. `openbao_bootstrap_tls_replace_existing=true` is only
needed when replacing an already-installed listener cert/key pair, and the
disabled bootstrap TLS auto-detection prevents old node certs from being used
instead of issuing from the sub-CA.

To build the public chain file on the signer node:

```bash
sudo scripts/openbao-build-subca-chain.sh \
  --subca-cert /usr/local/lib/openbao/subCA-example.at.cer \
  --issuer-cert /etc/pki/ca-trust/source/anchors/example-root.pem \
  --out /usr/local/lib/openbao/subCA-example.at-chain.pem
```

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
