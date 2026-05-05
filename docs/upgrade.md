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
- refuses package changes unless Raft membership matches inventory
- saves a Raft snapshot before changing any node that needs an upgrade
- upgrades standby nodes first
- stops before the active node if any required standby upgrade fails
- upgrades the active node last
- rechecks Raft membership after standby and active-node upgrades
- stops final validation if any required node upgrade did not complete
- validates every node is unsealed and running `openbao_version`

Snapshots are fetched to `secure-artifacts/` on the controller.

## Failure And Rerun Behavior

The upgrade policy is safe repair, not automatic rollback.

It is safe to rerun the same upgrade command after fixing a failed node.
Already upgraded nodes are skipped by running-version detection. If the target
package is installed but the old OpenBao process is still running, the playbook
restarts OpenBao and validates that the running version matches
`openbao_version`.

The playbook stops before package changes when a node is unreachable, sealed,
unhealthy, or missing from Raft as a voting peer. It also stops before upgrading
the active node if any required standby upgrade did not complete.

Common recovery steps:

- start or reconnect an unreachable node
- restart or unseal an unhealthy node
- repair Raft membership manually when peer IDs or addresses drift
- rerun `ansible-playbook playbooks/upgrade.yml --ask-vault-pass`

No rollback is attempted by Ansible. Use the saved Raft snapshot only for
operator-led recovery.
