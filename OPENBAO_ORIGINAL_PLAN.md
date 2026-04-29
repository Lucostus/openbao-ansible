# Original OpenBao HA Ansible Plan

## Summary

Build a repo-root Ansible project that deploys a three-node OpenBao HA cluster
on RHEL using integrated Raft storage, TLS, audit logging, static auto-unseal,
and a configurable external load balancer model.

The default test flow installs OpenBao `2.4.4`, validates the cluster, then
supports a rolling upgrade to OpenBao `2.5.3`, which was the current latest
release when this plan was written on April 29, 2026.

## References

- OpenBao install documentation
- OpenBao Raft integrated storage documentation
- OpenBao static seal documentation
- OpenBao TCP listener and listener ACME documentation
- OpenBao PKI ACME API documentation
- OpenBao PKI considerations
- GitHub releases `v2.4.4` and `v2.5.3`

## Repository Layout

Add these files at repository root:

- `ansible.cfg`
- `requirements.yml`
- `inventory/rhel10.ini`
- `group_vars/rhel10/main.yml`
- `group_vars/rhel10/vault.yml.example`
- `playbooks/site.yml`
- `playbooks/upgrade.yml`
- `playbooks/renew-certs.yml`
- `roles/openbao_common/`
- `roles/openbao_server/`
- `roles/openbao_bootstrap/`
- `roles/openbao_pki/`
- `roles/openbao_acme_client/`
- `roles/openbao_upgrade/`

## Public Variables

Core defaults:

```yaml
openbao_initial_version: "2.4.4"
openbao_target_version: "2.5.3"
openbao_arch: "amd64"
openbao_public_fqdn: "bao.example.com"
openbao_public_api_addr: "https://bao.example.com"
openbao_listener_port: 8200
openbao_cluster_port: 8201
openbao_lb_mode: "tcp_passthrough"
openbao_node_fqdn: "{{ inventory_hostname }}.example.com"
```

Sensitive variables in Ansible Vault:

```yaml
openbao_static_unseal_key_b64: "<32-byte base64 key>"
openbao_root_ca_cert_pem: |
  -----BEGIN CERTIFICATE-----
openbao_root_ca_key_pem: |
  -----BEGIN PRIVATE KEY-----
openbao_acme_dns_env: {}
```

TLS defaults:

```yaml
openbao_tls_bootstrap_cert_src: "files/bootstrap-tls/{{ inventory_hostname }}.fullchain.pem"
openbao_tls_bootstrap_key_src: "files/bootstrap-tls/{{ inventory_hostname }}.key.pem"
openbao_tls_mode: "file_acme"
openbao_acme_challenge: "dns-01"
openbao_acme_client: "lego"
openbao_acme_directory: "{{ openbao_public_api_addr }}/v1/pki_openbao/roles/openbao-listener/acme/directory"
```

Important TLS decision: for bootstrap file mode, each node gets one multi-SAN
listener certificate covering both the node direct FQDN and
`openbao_public_fqdn`. If the environment has two separate certificates, the
implementation should either merge issuance into one multi-SAN certificate or
use separate listeners and ports explicitly.

## Implementation Steps

1. Add Ansible collections:
   - `community.crypto`
   - `community.general`
   - `ansible.posix`
2. Add inventory using the provided hosts:
   - `rhel10-ansible-1 ansible_host=192.168.32.239 ansible_port=2221`
   - `rhel10-ansible-2 ansible_host=192.168.32.239 ansible_port=2224`
   - `rhel10-ansible-3 ansible_host=192.168.32.239 ansible_port=2225`
3. Preflight:
   - Confirm exactly three hosts.
   - Confirm RHEL, systemd, firewalld, and SELinux availability.
   - Confirm bootstrap TLS files exist.
   - Confirm static seal key decodes to exactly 32 bytes.
   - Confirm root CA certificate and key are present in vaulted variables.
   - Confirm direct node FQDNs and public or load balancer FQDN are set.
4. Install exact OpenBao RPMs from GitHub releases with checksum verification:
   - `2.4.4`: `bao_2.4.4_linux_amd64.rpm`
   - `2.5.3`: `openbao_2.5.3_linux_amd64.rpm`
   - Use `checksums-linux.txt` from the same release.
5. Configure system:
   - Create `/etc/openbao.d`, `/var/lib/openbao`,
     `/var/lib/openbao/raft`, `/var/log/openbao`,
     `/etc/openbao.d/tls`, and `/etc/openbao.d/seal`.
   - Install bootstrap TLS and CA files with restrictive permissions.
   - Open firewall ports `8200/tcp` and `8201/tcp`.
   - Optionally open `443/tcp` or `80/tcp` when listener ACME challenge mode
     requires them.
   - Add a systemd hardening drop-in with `NoNewPrivileges`, restricted write
     paths, and swap limiting where supported.
6. Render OpenBao config:
   - `storage "raft"` with `node_id`, `performance_multiplier = 1`, and
     `retry_join` for all peers.
   - `cluster_addr = https://<node_fqdn>:8201`.
   - `api_addr = https://<node_fqdn>:8200` by default.
   - TLS listener on `0.0.0.0:8200`.
   - `seal "static"` reading `/etc/openbao.d/seal/current.key`.
   - Load balancer, `X-Forwarded-For`, and proxy protocol options exposed as
     variables and disabled by default.
7. Bootstrap:
   - Start node 1.
   - Run `bao operator init -recovery-shares=5 -recovery-threshold=3 -format=json`.
   - Store init output only on the Ansible controller under
     `secure-artifacts/`, mode `0600`, never on OpenBao nodes.
   - Start and join nodes 2 and 3 through Raft `retry_join`.
   - Verify `bao status` and `bao operator raft list-peers`.
8. Configure production basics:
   - Enable file audit at `/var/log/openbao/audit.log`.
   - Enable `pki_openbao/`.
   - Generate an internal intermediate CSR inside OpenBao.
   - Sign the intermediate with the vaulted root CA.
   - Import the signed intermediate back into OpenBao.
   - Configure issuing, CRL, OCSP, and ACME URLs to use
     `openbao_public_api_addr`.
9. Configure OpenBao ACME:
   - Tune ACME headers:
     - `Replay-Nonce`
     - `Link`
     - `Location`
     - `Last-Modified`
   - Create role `openbao-listener` for exact names: public or load balancer
     FQDN plus all node FQDNs.
   - Set `no_store=false`, server auth only, and TTL/max TTL no greater than
     90 days.
   - Enable ACME with `eab_policy=always-required`.
   - Generate per-node EAB credentials and store them as controller-side secure
     artifacts.
10. Certificate renewal:
    - Default mode is `file_acme` using `lego` against OpenBao's ACME endpoint.
    - Default challenge is `dns-01` because it works reliably for shared and
      direct names behind TCP passthrough.
    - Install a systemd timer per node to renew the multi-SAN certificate and
      send `SIGHUP` to OpenBao after successful renewal.
    - Also support `listener_acme` for OpenBao `2.5.x` with HTTP or
      TLS-ALPN variables, but fail preflight if shared-domain challenge routing
      or shared cache is not confirmed.
11. Rolling upgrade:
    - `playbooks/upgrade.yml` takes a Raft snapshot first.
    - Upgrade one node at a time with `serial: 1`.
    - Prefer standby nodes first and active node last.
    - After each node, wait for service, auto-unseal, TLS health, and Raft peer
      health.
    - Final acceptance requires three voters, one active node, two standby
      nodes, and version `2.5.3`.

## Test And Acceptance Criteria

- `ansible-playbook --syntax-check playbooks/site.yml`
- `ansible-playbook --syntax-check playbooks/upgrade.yml`
- `ansible-playbook --syntax-check playbooks/renew-certs.yml`
- `ansible-lint`
- `yamllint`
- Preflight fails clearly for:
  - Missing certificates
  - Bad static seal key
  - Missing root CA
  - Impossible ACME challenge mode
- After deploy:
  - All three nodes report initialized and unsealed.
  - Raft has three voting peers.
  - TLS validates for node FQDNs and shared FQDN.
  - Audit log exists and receives entries.
  - `pki_openbao` has a signed intermediate and ACME enabled.
  - A test ACME issuance succeeds for a configured node or public name.
- After upgrade:
  - Cluster remains available during serial upgrade.
  - Final version is `2.5.3` on all nodes.
  - Raft peers and TLS health remain clean.

## Assumptions And Defaults

- Root CA material in Ansible Vault is accepted by request. Production best
  practice would normally keep the root CA offline.
- Static auto-unseal is accepted because no KMS, HSM, or other external secret
  holder is available. This is operationally useful but weaker than KMS or
  HSM-backed auto-unseal.
- The load balancer itself is not managed by Ansible. The playbook only exposes
  load-balancer-aware variables.
- DNS names are placeholders until real production names are supplied.
- Default ACME renewal uses an external ACME client against OpenBao's ACME
  server. OpenBao still issues its own future listener certificates, while this
  avoids load-balancer challenge-routing problems.

## ACME Challenge Clarification

OpenBao's PKI ACME server supports these challenge types:

- `http-01`
- `dns-01`
- `tls-alpn-01`

The Ansible implementation must make the challenge configurable. The default is
`dns-01`, with `file_acme` and `lego`, because it is the most reliable model
for a TCP passthrough load balancer and a shared public FQDN.
