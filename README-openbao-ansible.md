# OpenBao HA Ansible Deployment

This repository includes a repo-root Ansible project for a three-node OpenBao
cluster on RHEL. It deploys OpenBao with integrated Raft storage, TLS, static
auto-unseal, file audit logging, an internal PKI intermediate, ACME issuance,
and systemd-based listener certificate renewal.

The repository is now scoped to this OpenBao Ansible deployment.

## Files

- `inventory/rhel10.ini` contains the three provided RHEL hosts. The optional
  host variables `bao_internal_ip` and `bao_fqdn` are treated as aliases for
  the OpenBao Raft peer IP and node FQDN.
- `group_vars/rhel10/main.yml` contains non-secret defaults.
- `group_vars/rhel10/vault.yml.example` shows the required vaulted values.
- `files/bootstrap-tls/` is where first-run listener certificates are placed.
- `secure-artifacts/` is generated locally and intentionally ignored by git.

## Required Operator Inputs

Create and encrypt `group_vars/rhel10/vault.yml`:

```bash
cp group_vars/rhel10/vault.yml.example group_vars/rhel10/vault.yml
ansible-vault encrypt group_vars/rhel10/vault.yml
```

Required values:

- `openbao_static_unseal_key_b64`: base64 for exactly 32 raw bytes.
- `openbao_root_ca_cert_pem`: root CA certificate.
- `openbao_root_ca_key_pem`: root CA key, used to sign the OpenBao intermediate.
- `openbao_acme_dns_env`: DNS provider credentials when `dns-01` is used.

Place bootstrap TLS files under `files/bootstrap-tls/` using the default names
documented there. Each node certificate should include both the node direct FQDN
and the shared `openbao_public_fqdn`.

The OpenBao listener is TLS-enabled by default, so the effective
`openbao_api_addr`, `openbao_cluster_addr`, and `openbao_cli_addr` defaults use
`https://`. If a lab inventory exposes host-side NAT ports for SSH or testing,
keep those as separate variables instead of changing the in-cluster OpenBao
addresses to `http://`.

## Install Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

## Deploy Initial Version

The default deployment installs OpenBao `2.4.4`.

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Generated bootstrap output and EAB credentials are stored under
`secure-artifacts/` on the Ansible controller only.

## Certificate Renewal

Default renewal mode is:

```yaml
openbao_tls_mode: file_acme
openbao_acme_client: lego
openbao_acme_challenge: dns-01
```

Supported challenge values are `dns-01`, `http-01`, and `tls-alpn-01`. The
managed external client implementation currently uses `lego`; `certbot` and
`acme.sh` are reserved variable values for future role extension. Per-node
renewal requests `openbao_public_fqdn` plus that node's `openbao_node_fqdn`;
the OpenBao ACME role allows the public FQDN and all node FQDNs.

Run a manual renewal:

```bash
ansible-playbook playbooks/renew-certs.yml --ask-vault-pass
```

## Rolling Upgrade

The default target version is OpenBao `2.5.3`.

```bash
ansible-playbook playbooks/upgrade.yml --ask-vault-pass
```

The upgrade playbook saves a Raft snapshot, upgrades standby nodes first, then
the active node, and validates the final version and unsealed state.

## Validation

```bash
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/upgrade.yml
ansible-playbook --syntax-check playbooks/renew-certs.yml
```

Optional:

```bash
ansible-lint
yamllint .
```
