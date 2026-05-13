# Bootstrap TLS Files

Place first-run listener certificates here when using controller bootstrap TLS
with:

```yaml
openbao_bootstrap_tls_source: controller
```

Default production `bootstrap` and `agent` deployments instead read one
bootstrap cert/key pair per host from each managed node under
`/usr/local/lib/cockpitcert/`, copy it once into `/etc/openbao.d/tls`, and then
optionally let `openbao-agent` own renewal. This directory remains the default
source for the local lab and for controller-file fallback deployments.

If no node-side real cert/key pair exists yet and
`openbao_bootstrap_tls_missing_strategy=generate_self_signed`, Ansible generates
a temporary bootstrap CA plus per-node listener certificates under ignored
`secure-artifacts/<group>/bootstrap-selfsigned/`. Put the real per-node files in
place later and rerun `playbooks/site.yml` to replace the generated listener
certificates.

As an alternative, `openbao_bootstrap_tls_missing_strategy=issue_from_node_subca`
can issue first-run listener certificates from a subordinate CA already present
on one OpenBao node or on all OpenBao nodes. The generated listener private key
stays on its target node; delegated signing moves only CSRs and public
certificates.

Controller bootstrap uses one pair per inventory host. Expected default names:

- `rhel10-ansible-1.fullchain.pem`
- `rhel10-ansible-1.key.pem`
- `rhel10-ansible-2.fullchain.pem`
- `rhel10-ansible-2.key.pem`
- `rhel10-ansible-3.fullchain.pem`
- `rhel10-ansible-3.key.pem`

Each certificate should include SANs for the node FQDN and the shared
`openbao_public_fqdn`, unless you override the TLS variables in `group_vars`.
