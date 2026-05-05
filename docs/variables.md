# Variables

## Usually Edited

Edit `group_vars/rhel10/main.yml` for site-specific values:

- `openbao_version`
- `openbao_public_fqdn`
- `openbao_public_api_addr`
- `openbao_nodes`
- `openbao_certificate_mode`
- `openbao_bootstrap_tls_source`
- `openbao_node_bootstrap_tls_dir`
- `openbao_manage_hosts_entries`
- `openbao_manage_firewalld`
- `openbao_manage_selinux`

`openbao_nodes` is the source of each node's OpenBao FQDN and peer IP:

```yaml
openbao_nodes:
  rhel10-ansible-1:
    fqdn: bao1.example.com
    ip: 10.0.0.11
```

## Secrets

Create `group_vars/rhel10/vault.yml` from the example and encrypt it.

Required:

- `openbao_static_unseal_key_b64`
- `openbao_root_ca_cert_pem`
- `openbao_root_ca_key_pem`

## Defaults

Most low-level settings are in `group_vars/all/openbao_defaults.yml`, including:

- package URLs, checksums, and release architecture
- filesystem paths and service user/group
- listener and cluster ports
- PKI mount names, role names, and TTLs
- OpenBao Agent paths and AppRole defaults
- native ACME fallback settings
- audit, hardening, and artifact path defaults

These are intended to be stable defaults. Override them only when the target
environment requires it.

## Certificate Modes

```yaml
openbao_certificate_mode: agent       # default, preferred
openbao_certificate_mode: native_acme # advanced fallback
openbao_certificate_mode: bootstrap   # bootstrap TLS only
```

`agent` installs OpenBao Agent after the cluster and PKI are ready. The Agent
uses per-node AppRole credentials to issue listener certificates from OpenBao
PKI and replaces the bootstrap listener cert/key pair.

`bootstrap` deploys OpenBao with only the supplied listener certificates. It
does not create per-node Agent AppRole artifacts, install `openbao-agent`, or
rotate listener certificates. This is useful when the first deployment should
depend only on cert/key material that already exists on the nodes.

`native_acme` keeps OpenBao listener ACME available as an advanced fallback.
See `docs/native-listener-acme.md`.

Bootstrap TLS sources:

```yaml
openbao_bootstrap_tls_source: node       # default for agent and bootstrap modes
openbao_bootstrap_tls_source: controller # lab or fallback
```

`node` reads first-run cert/key material from each managed node. By default the
role auto-detects files under `openbao_node_bootstrap_tls_dir`; explicit paths
can be set with `openbao_node_bootstrap_tls_cert` and
`openbao_node_bootstrap_tls_key`.

`controller` reads cert/key material from the Ansible controller using
`openbao_controller_bootstrap_tls_cert` and
`openbao_controller_bootstrap_tls_key`. The Docker lab uses this path.

## Bootstrap First, Agent Later

Start without Agent:

```yaml
openbao_certificate_mode: bootstrap
openbao_bootstrap_tls_source: node
openbao_node_bootstrap_tls_dir: /usr/local/lib/cockpitcert
```

Later enable Agent renewal by changing only:

```yaml
openbao_certificate_mode: agent
```

Then rerun:

```bash
ansible-playbook playbooks/site.yml
```

The rerun reuses the initialized cluster and existing OpenBao PKI, creates any
missing per-node Agent AppRole artifacts, installs `openbao-agent`, and replaces
the bootstrap listener certs with Agent-issued certs.

## Renamed Variables

Old names are not kept as compatibility aliases.

| Old | New |
| --- | --- |
| `openbao_arch` | `openbao_release_arch` |
| `openbao_tls_mode` | `openbao_certificate_mode` |
| `openbao_tls_bootstrap_source` | `openbao_bootstrap_tls_source` |
| `openbao_tls_bootstrap_remote_dir` | `openbao_node_bootstrap_tls_dir` |
| `openbao_tls_bootstrap_remote_cert_src` | `openbao_node_bootstrap_tls_cert` |
| `openbao_tls_bootstrap_remote_key_src` | `openbao_node_bootstrap_tls_key` |
| `openbao_acme_challenge` | `openbao_native_acme_challenge` |
| `openbao_listener_acme_*` | `openbao_native_acme_*` |
| `bao_fqdn` | `openbao_nodes.<host>.fqdn` |
| `bao_internal_ip` | `openbao_nodes.<host>.ip` |
