# Variables

## Usually Edited

Edit `group_vars/<target>/main.yml` for site-specific values. The default
target is `rhel10`; prod/test runs select `openbao-prod` or `openbao-test` with
`openbao_target_group`.

- `openbao_target_group`
- `openbao_version`
- `openbao_public_fqdn`
- `openbao_public_api_addr`
- `openbao_nodes`
- `openbao_certificate_mode`
- `openbao_bootstrap_tls_source`
- `openbao_node_bootstrap_tls_dir`
- `openbao_bootstrap_tls_missing_strategy`
- `openbao_manage_hosts_entries`
- `openbao_tls_trust_source`
- `openbao_manage_firewalld`
- `openbao_manage_selinux`

DNS-only prod/test inventories do not need `openbao_nodes`; each host's
`ansible_host` becomes `openbao_node_fqdn`:

```yaml
openbao-prod:
  hosts:
    aspsecret1:
      ansible_host: lagaspsecret1.example.at
```

Use `openbao_nodes` only when you need to override each node's OpenBao FQDN or
provide explicit peer IPs for managed `/etc/hosts` entries:

```yaml
openbao_nodes:
  rhel10-ansible-1:
    fqdn: bao1.example.com
    ip: 10.0.0.11
```

## Secrets

Bootstrap mode does not require `group_vars/<target>/vault.yml`. Listener
TLS material is read from the selected hosts, and the static seal key is
generated once under ignored `secure-artifacts/<target>/static-unseal.key.b64`.

Create and encrypt `group_vars/<target>/vault.yml` only when you enable Agent
or native ACME renewal with variable-based PKI signing.

Renewal-mode PKI values:

- `openbao_root_ca_cert_pem`
- `openbao_root_ca_key_pem`

Legacy static seal input is still supported by setting
`openbao_static_seal_source=variable` and `openbao_static_unseal_key_b64`.

## Defaults

Most low-level settings are in `group_vars/all/openbao_defaults.yml`, including:

- package URLs, checksums, and release architecture
- filesystem paths and service user/group
- listener and cluster ports
- target-group selection and environment-scoped artifact paths
- PKI mount names, role names, and TTLs
- OpenBao Agent paths and AppRole defaults
- native ACME fallback settings
- audit, hardening, and artifact path defaults

These are intended to be stable defaults. Override them only when the target
environment requires it.

## Certificate Modes

```yaml
openbao_certificate_mode: bootstrap   # default, provided or generated bootstrap TLS
openbao_certificate_mode: agent       # later Agent-managed renewal
openbao_certificate_mode: native_acme # advanced fallback
```

`bootstrap` deploys OpenBao with only bootstrap listener certificates. It uses
real per-node cert/key files when present, or generates temporary self-signed
bootstrap material when those files are absent and
`openbao_bootstrap_tls_missing_strategy=generate_self_signed`. It does not
configure OpenBao PKI, create per-node Agent AppRole artifacts, install
`openbao-agent`, or rotate listener certificates. This is the default fresh
production path.

`agent` installs OpenBao Agent after the cluster and PKI are ready. The Agent
uses per-node AppRole credentials to issue listener certificates from OpenBao
PKI and replaces the bootstrap listener cert/key pair.

`native_acme` keeps OpenBao listener ACME available as an advanced fallback.
See `docs/native-listener-acme.md`.

Bootstrap TLS sources:

```yaml
openbao_bootstrap_tls_source: node       # default for agent and bootstrap modes
openbao_bootstrap_tls_source: controller # lab or fallback
```

`node` reads first-run cert/key material from each managed node. The default
layout expects one certificate and key pair per host under
`openbao_node_bootstrap_tls_dir`, with inventory-host names preferred:

```yaml
openbao_node_bootstrap_tls_dir: /usr/local/lib/cockpitcert
# /usr/local/lib/cockpitcert/{{ inventory_hostname }}.fullchain.pem
# /usr/local/lib/cockpitcert/{{ inventory_hostname }}.key.pem
```

The role also auto-detects files named after `openbao_node_fqdn`,
`ansible_hostname`, or `ansible_fqdn`, then falls back to legacy generic names
such as `fullchain.pem`, `cert.pem`, `key.pem`, and `privkey.pem`.

For unusual per-host names, set explicit templated paths:

```yaml
openbao_node_bootstrap_tls_cert: "{{ openbao_node_bootstrap_tls_dir }}/{{ inventory_hostname }}-server.fullchain.pem"
openbao_node_bootstrap_tls_key: "{{ openbao_node_bootstrap_tls_dir }}/{{ inventory_hostname }}-server.key.pem"
```

When no real node cert/key files exist yet, the default missing-file strategy
generates a temporary bootstrap CA and per-node leaf certificates on the
controller:

```yaml
openbao_bootstrap_tls_missing_strategy: generate_self_signed
openbao_bootstrap_selfsigned_artifacts_dir: "{{ openbao_secure_artifacts_dir }}/bootstrap-selfsigned"
```

The generated CA is installed on each node as the effective `openbao_ca_cert_file`
so CLI checks, Raft retry-join, and listener validation continue to verify TLS.
Generated material is not production certificate material and stays under ignored
`secure-artifacts/`.

If real certs should be mandatory, set:

```yaml
openbao_bootstrap_tls_missing_strategy: fail
```

A partial real pair always fails. This prevents drifting into generated
certificates when a certificate was copied without its matching key, or the key
was copied without its matching certificate.

`controller` reads cert/key material from the Ansible controller using
`openbao_controller_bootstrap_tls_cert` and
`openbao_controller_bootstrap_tls_key`. The Docker lab uses this path.

## Bootstrap First, Agent Later

Start with the default bootstrap-only mode:

```yaml
openbao_certificate_mode: bootstrap
openbao_bootstrap_tls_source: node
openbao_node_bootstrap_tls_dir: /usr/local/lib/cockpitcert
openbao_bootstrap_tls_missing_strategy: generate_self_signed
```

If real certs are not present yet, this first run uses generated temporary
bootstrap certificates. Place the real files later at the configured per-node
paths and rerun `playbooks/site.yml`; the playbook replaces the generated
listener cert/key pair and returns to the configured trust source.

Later enable Agent renewal by changing only:

```yaml
openbao_certificate_mode: agent
```

Then rerun:

```bash
ansible-playbook playbooks/site.yml
```

Before enabling Agent renewal, provide a PKI signing source such as vaulted
`openbao_root_ca_cert_pem` and `openbao_root_ca_key_pem`. The rerun reuses the
initialized cluster, configures OpenBao PKI, creates any missing per-node Agent
AppRole artifacts, installs `openbao-agent`, and replaces the bootstrap
listener certs with Agent-issued certs.

## Static Seal

Default prod/test bootstrap uses:

```yaml
openbao_static_seal_source: generated_artifact
```

The controller stores one generated key per selected group:

```text
secure-artifacts/openbao-prod/static-unseal.key.b64
secure-artifacts/openbao-test/static-unseal.key.b64
```

If all selected nodes already have the same key at
`openbao_static_unseal_key_path`, the playbook adopts it into the controller
artifact. If node keys differ from the artifact, the playbook fails rather than
overwriting seal material.

## TLS Trust

Default prod/test bootstrap uses the RHEL system trust bundle:

```yaml
openbao_tls_trust_source: system
openbao_ca_cert_file: /etc/pki/tls/certs/ca-bundle.crt
```

For a private CA already present on every node, use:

```yaml
openbao_tls_trust_source: file
openbao_tls_trust_file: /path/to/ca.pem
```

For the legacy vaulted CA flow, keep `openbao_root_ca_cert_pem` in
`group_vars/<target>/vault.yml`; the default trust source switches to
`variable` when that value is present.

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
