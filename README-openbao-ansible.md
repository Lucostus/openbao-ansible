# OpenBao HA Ansible Deployment

This repository includes a repo-root Ansible project for a three-node OpenBao
cluster on RHEL. It deploys OpenBao with integrated Raft storage, TLS, static
auto-unseal, file audit logging, an internal PKI intermediate, and per-node
OpenBao Agent listener certificate renewal. Native listener ACME with a shared
cache remains available as an explicit fallback mode.

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

## Local Docker Lab

The local lab builds three UBI 10 systemd containers with SSH enabled and an
HAProxy TCP passthrough load balancer. Generated keys, bootstrap TLS material,
root CA material, and lab vault variables are written only under ignored paths.

```bash
scripts/openbao-lab-generate-inputs.sh
docker compose -f compose.openbao-lab.yml up -d --build
ansible -i inventory/docker-rhel10.ini rhel10 -m ping \
  --private-key secure-artifacts/lab/ssh/id_ed25519
scripts/openbao-lab-playbook.sh site
curl --resolve bao.lab.local:8443:127.0.0.1 \
  --cacert secure-artifacts/lab/ca/root-ca.pem \
  https://bao.lab.local:8443/v1/sys/health
scripts/openbao-lab-playbook.sh upgrade
```

On this Apple Silicon Docker host the lab compose file uses `linux/arm64` and
sets the lab-only `openbao_arch: arm64`, because the UBI 10 `linux/amd64` image
requires x86-64-v3 CPU features that Docker's current emulation does not expose.
Production defaults remain unchanged.

To reset the lab containers and Docker volumes back to a fresh state while
keeping the generated lab CA, SSH key, vault file, and bootstrap TLS inputs:

```bash
scripts/openbao-lab-reset.sh --start
scripts/openbao-lab-playbook.sh site
```

To also regenerate all lab-only inputs:

```bash
scripts/openbao-lab-reset.sh --all --build
scripts/openbao-lab-playbook.sh site
```

## Deploy Desired Version

Set the desired OpenBao version in `group_vars/rhel10/main.yml`:

```yaml
openbao_version: "2.5.3"
```

Fresh deployments install that exact version.

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Generated bootstrap output and reusable per-node OpenBao Agent AppRole
artifacts are stored under `secure-artifacts/` on the Ansible controller.
Those artifacts are installed only on their matching nodes as root-owned
`role_id` and `secret_id` files for the local `openbao-agent` service.

## Agent PKI Renewal

Default listener certificate mode is:

```yaml
openbao_tls_mode: agent_pki
openbao_agent_cert_dns_names:
  - "{{ openbao_public_fqdn }}"
  - "{{ openbao_node_fqdn }}"
```

The first site run starts OpenBao with the operator-supplied bootstrap TLS
files, initializes and unseals the cluster, configures PKI, creates a
least-privilege per-node AppRole, then serially starts `openbao-agent` on each
node. The agent requests a listener certificate from that node's PKI role,
renders a single bundle, and runs a root-owned hook that validates and splits
the bundle into `openbao.fullchain.pem` and `openbao.key.pem` before restarting
OpenBao.

Agent-issued listener certificates include both the shared public FQDN and the
node FQDN by default. Renewal does not require NFS, CertMagic, ACME challenge
routing, or an external ACME client.

## Optional Listener ACME

Native listener ACME is still available when explicitly selected:

```yaml
openbao_tls_mode: listener_acme
openbao_acme_challenge: tls-alpn-01
openbao_listener_acme_cache_nfs_src: nfs-server.example.com:/exports/openbao-acme
openbao_listener_acme_tls_alpn_routed: true
```

When listener ACME is active, generated EAB artifacts are stored under
`secure-artifacts/` and node-specific EAB values are rendered into
`/etc/openbao.d/openbao.hcl`, installed as `0640` for `root:openbao`. The NFS
export must be reachable by all three OpenBao nodes; Ansible mounts it at
`openbao_listener_acme_cache_path` and validates that the `openbao` service user
can write there.

The default `tls-alpn-01` challenge assumes the L4 load balancer forwards
`openbao_public_fqdn:443` to the OpenBao listener and preserves TCP/TLS
passthrough, including ALPN. Set `openbao_listener_acme_tls_alpn_routed=true`
only after that routing is in place.

## Migrating Certificate Modes

To migrate an existing listener ACME deployment to the default agent-managed
PKI mode, set `openbao_tls_mode: agent_pki`, keep the bootstrap TLS files
available, and rerun `playbooks/site.yml`. Ansible removes the managed NFS
mount from the nodes while preserving the remote export data.

To roll back to listener ACME, set `openbao_tls_mode: listener_acme`, restore
the ACME/NFS variables, and rerun `playbooks/site.yml`.

## Rolling Upgrade

To upgrade an existing cluster, change only `openbao_version`, then run the
rolling upgrade playbook:

```bash
ansible-playbook playbooks/upgrade.yml --ask-vault-pass
```

The upgrade playbook reads the running version on every node, rejects
downgrades, saves a Raft snapshot only when a version change is needed,
upgrades standby nodes first, then the active node, and validates the desired
version and unsealed state.

## Validation

```bash
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/upgrade.yml
ansible-inventory --graph
```

Optional:

```bash
ansible-lint
yamllint .
```
