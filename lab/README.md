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

Reset while keeping generated inputs:

```bash
lab/scripts/openbao-lab-reset.sh --start
```

Reset and regenerate inputs:

```bash
lab/scripts/openbao-lab-reset.sh --all --build
```
