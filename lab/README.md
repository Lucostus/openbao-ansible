# Docker Lab

The lab runs three UBI systemd containers and an HAProxy TCP passthrough load
balancer. Generated keys, certs, vault values, and OpenBao artifacts are written
only under ignored paths.

Run:

```bash
lab/scripts/openbao-lab-generate-inputs.sh
docker compose -f lab/compose.yml up -d --build
lab/scripts/openbao-lab-playbook.sh site
```

The default lab run uses bootstrap listener TLS and does not start
`openbao-agent`.

Health check:

```bash
curl --resolve bao.lab.local:8443:127.0.0.1 \
  --cacert secure-artifacts/lab/ca/root-ca.pem \
  https://bao.lab.local:8443/v1/sys/health
```

Upgrade test:

```bash
lab/scripts/openbao-lab-playbook.sh upgrade
```

Bootstrap-to-Agent test:

```bash
lab/scripts/openbao-lab-playbook.sh site -e openbao_certificate_mode=agent
```

The first run initializes OpenBao and keeps the supplied bootstrap listener
certificates without starting `openbao-agent`. The second run creates per-node
Agent AppRole artifacts under `secure-artifacts/lab/openbao/`, starts
`openbao-agent`, and validates Agent-issued listener certificates for
`bao.lab.local` and each node FQDN.

Node sub-CA bootstrap and Agent renewal with the actual sub-CA imported into
OpenBao:

```bash
lab/scripts/openbao-lab-reset.sh --all --build
lab/scripts/openbao-lab-generate-inputs.sh
docker compose -f lab/compose.yml up -d --build
lab/scripts/openbao-lab-install-subca.sh one
lab/scripts/openbao-lab-playbook.sh site \
  -e openbao_certificate_mode=agent \
  -e openbao_bootstrap_tls_source=node \
  -e openbao_bootstrap_tls_missing_strategy=issue_from_node_subca \
  -e openbao_pki_signing_source=node_subca_import \
  -e openbao_node_subca_import_private_key_to_openbao=true \
  -e openbao_node_subca_chain_file=/etc/openbao-subca/subca-chain-built.pem \
  -e openbao_node_subca_chain_issuer_path=/etc/pki/ca-trust/source/anchors
curl --resolve bao.lab.local:8443:127.0.0.1 \
  --cacert secure-artifacts/lab/subca/subca-chain.pem \
  https://bao.lab.local:8443/v1/sys/health
```

This mode is for a sub-CA that can issue leaf certificates but cannot issue
another CA. OpenBao Agent-issued listener certificates are signed directly by
the imported actual sub-CA. The private key is sent from the selected signer
host to OpenBao over TLS and stored in OpenBao PKI storage; it is not copied to
the controller or to other nodes as a file.

All-node sub-CA bootstrap uses the same extra vars after installing the lab
sub-CA on every node:

```bash
lab/scripts/openbao-lab-install-subca.sh all
```

Full staged test from clean volumes:

```bash
lab/scripts/openbao-lab-reset.sh --all --build
lab/scripts/openbao-lab-playbook.sh site
lab/scripts/openbao-lab-playbook.sh site -e openbao_certificate_mode=agent
```

Reset while keeping generated inputs:

```bash
lab/scripts/openbao-lab-reset.sh --start
```

Reset and regenerate inputs:

```bash
lab/scripts/openbao-lab-reset.sh --all --build
```
