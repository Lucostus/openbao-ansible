# Rolling Upgrades

Upgrade by changing only:

```yaml
openbao_version: "x.y.z"
```

Then run:

```bash
ansible-playbook playbooks/upgrade.yml --ask-vault-pass
```

The upgrade playbook:

- reads the running version on every node before package changes
- rejects downgrades
- saves a Raft snapshot before changing any node that needs an upgrade
- upgrades standby nodes first
- upgrades the active node last
- validates every node is unsealed and running `openbao_version`

Snapshots are fetched to `secure-artifacts/` on the controller.
