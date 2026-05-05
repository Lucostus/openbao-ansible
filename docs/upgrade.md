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

- checks that every OpenBao node is reachable before it starts
- reads the running version on every node before package changes
- rejects downgrades
- saves a Raft snapshot before changing any node that needs an upgrade
- upgrades standby nodes first
- stops before the active node if any required standby upgrade fails
- upgrades the active node last
- stops final validation if any required node upgrade did not complete
- validates every node is unsealed and running `openbao_version`

Snapshots are fetched to `secure-artifacts/` on the controller.

If a node is unreachable, sealed, unavailable, or fails its health check, the
playbook aborts before continuing the rolling upgrade. Fix the failed node,
confirm the cluster is healthy, then rerun the same upgrade command. Already
upgraded nodes are detected by their running version and are not downgraded.
