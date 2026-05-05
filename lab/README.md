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
