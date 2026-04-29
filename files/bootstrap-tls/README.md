# Bootstrap TLS Files

Place first-run listener certificates here before running `playbooks/site.yml`.

Expected default names:

- `rhel10-ansible-1.fullchain.pem`
- `rhel10-ansible-1.key.pem`
- `rhel10-ansible-2.fullchain.pem`
- `rhel10-ansible-2.key.pem`
- `rhel10-ansible-3.fullchain.pem`
- `rhel10-ansible-3.key.pem`

Each certificate should include SANs for the node FQDN and the shared
`openbao_public_fqdn`, unless you override the TLS variables in `group_vars`.
