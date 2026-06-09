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
or all OpenBao nodes can instead use `openbao_pki_signing_source=node_subca_import`
to import the actual sub-CA into OpenBao, or `node_subca` when that sub-CA is
allowed to sign another intermediate CA. Then rerun. Use `--ask-vault-pass`
only when encrypted vault variables are needed:

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

Vaulted PKI values for variable-based renewal modes:

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

If one node, or every node, has a leaf-issuing subordinate CA at
`/etc/openbao-subca/`, use node-subCA bootstrap and import the actual sub-CA
into OpenBao for Agent renewal:

```yaml
openbao_certificate_mode: agent
openbao_bootstrap_tls_source: node
openbao_bootstrap_tls_missing_strategy: issue_from_node_subca
openbao_bootstrap_tls_replace_existing: true
openbao_pki_signing_source: node_subca_import
openbao_node_subca_import_private_key_to_openbao: true
openbao_node_subca_topology: auto
openbao_node_bootstrap_tls_autodetect: false
openbao_node_subca_chain_file: /etc/openbao-subca/subca-chain.pem
openbao_node_subca_chain_issuer_path: /etc/pki/ca-trust/source/anchors
```

With one complete sub-CA host, that host signs bootstrap CSRs for the cluster.
With complete sub-CA material on all three hosts, each node signs bootstrap
certificates locally. In `node_subca_import` mode the selected sub-CA private
key is sent over TLS to OpenBao and stored in OpenBao PKI storage; it is not
copied to the controller or to other nodes as a file. Use
`openbao_pki_signing_source=node_subca` only when the sub-CA is allowed to sign
an OpenBao intermediate CA. Use a chain file containing the sub-CA and its
issuer chain when the sub-CA is not a self-signed trust anchor.
`openbao_node_subca_cert_file` must be the actual CA certificate, not a
listener certificate issued by that CA; the certificate must have `CA:TRUE` and
certificate-signing key usage. A `.cer` extension is fine when OpenSSL can parse
the file as PEM or DER X.509.
`openbao_bootstrap_tls_replace_existing=true` is only needed when replacing an
already-installed listener cert/key pair, and the disabled bootstrap TLS
auto-detection prevents old node certs from being used instead of issuing from
the sub-CA. When `openbao_node_subca_chain_issuer_path` points at a PEM
issuer/root file or a directory such as `/etc/pki/ca-trust/source/anchors`,
Ansible builds `openbao_node_subca_chain_file` on the sub-CA host before
topology detection. Directory inputs are scanned for certificates, but only CA
certificates are included; leaf/listener certificates and non-cert files are
ignored. Root/issuer chain files are trust material only; they are not imported
as extra OpenBao PKI issuers.

When troubleshooting node sub-CA inputs, run the read-only diagnostic playbook:

```bash
ansible-playbook playbooks/diagnose_node_subca.yml
```

Use this first if deployment reports `is not a CA certificate. It appears to
be a leaf/listener certificate.` The configured sub-CA certificate must report
`Basic Constraints: CA:TRUE` and `Key Usage: Certificate Sign`; `pathlen:0` is
valid for issuing listener leaf certificates. A `.cer` extension is fine when
OpenSSL can parse the file as PEM or DER X.509.

For offline preparation or manual troubleshooting, the same public chain can be
built on the signer node with:

```bash
sudo scripts/openbao-build-subca-chain.sh \
  --subca-cert /usr/local/lib/openbao/subCA-example.at.cer \
  --issuer-cert /etc/pki/ca-trust/source/anchors \
  --out /usr/local/lib/openbao/subCA-example.at-chain.pem
```

`--issuer-cert` may be a single PEM file or a directory such as
`/etc/pki/ca-trust/source/anchors`; when it is a directory, only CA
certificates from that directory are included in the public issuer bundle.

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

## Replace Existing Deployment

To intentionally destroy and recreate the selected OpenBao deployment, set:

```yaml
openbao_replace_existing: true
```

Then run the site playbook for the target group:

```bash
ansible-playbook -i inventory/openbao.yml playbooks/site.yml \
  -e openbao_target_group=openbao-prod
```

Every `playbooks/site.yml` run while `openbao_replace_existing` is true wipes
and recreates the selected cluster. Leave it false unless repeated replacement
is intentional.

Replacement deletes the Ansible-managed OpenBao footprint: remote OpenBao
config, data, Raft state, static seal material, installed listener TLS copies,
logs, package cache, systemd units, Agent config/state, generated node-subCA
bootstrap output, and the selected controller artifact directory
`openbao_secure_artifacts_dir`, including init JSON, static seal key artifacts,
Agent AppRole artifacts, generated self-signed certificates, and snapshots.

Replacement preserves external operator inputs: inventory, `group_vars`,
vaulted variables, uploaded bootstrap TLS source files, uploaded node sub-CA
certificate/key material, issuer directories, `files/bootstrap-tls/`, installed
packages, service user/group, firewalld rules, and SELinux port rules.

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
