# Bootstrap TLS Files

Place first-run listener certificates here when using controller bootstrap TLS
with:

```yaml
openbao_bootstrap_tls_source: controller
```

Default production `agent` deployments instead read bootstrap cert/key
material from each managed node under `/usr/local/lib/cockpitcert/`, copy it
once into `/etc/openbao.d/tls`, and then let `openbao-agent` own renewal. This
directory remains the default source for the local lab and for controller-file
fallback deployments.

Expected default names:

- `rhel10-ansible-1.fullchain.pem`
- `rhel10-ansible-1.key.pem`
- `rhel10-ansible-2.fullchain.pem`
- `rhel10-ansible-2.key.pem`
- `rhel10-ansible-3.fullchain.pem`
- `rhel10-ansible-3.key.pem`

Each certificate should include SANs for the node FQDN and the shared
`openbao_public_fqdn`, unless you override the TLS variables in `group_vars`.
