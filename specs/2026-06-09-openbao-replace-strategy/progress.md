# Progress: OpenBao Replace Existing Strategy

**Spec:** [spec.md](./spec.md)
**Started:** 2026-06-09
**Status:** complete

---

## Setup: Persist Spec Artifacts
- **Status:** done
- **Result:** Created research, spec, and progress files for the approved plan.
- **Files modified:**
  - `specs/2026-06-09-openbao-replace-strategy/research.md`
  - `specs/2026-06-09-openbao-replace-strategy/spec.md`
  - `specs/2026-06-09-openbao-replace-strategy/progress.md`
- **Decisions made:** Used the user-approved spec path.
- **Blockers/gaps:** None.

## Step 1: Add Defaults And Known Variable Support
- **Status:** done
- **Result:** Added `openbao_replace_existing: false` to the shared defaults.
- **Files modified:**
  - `group_vars/all/openbao_defaults.yml`
- **Decisions made:** None.
- **Blockers/gaps:** None.

## Step 2: Add Replacement Task File
- **Status:** done
- **Result:** Created the replacement task file, including controller artifact
  deletion, service shutdown, managed systemd cleanup, safety assertions, remote
  managed path deletion, and preservation checks for uploaded TLS/CA inputs.
- **Files modified:**
  - `roles/openbao_common/tasks/replace_existing.yml`
- **Decisions made:** Included `openbao_tls_trust_file` in preserved operator
  CA inputs and routed generated node-subCA chain removal through the managed
  path safety assertions.
- **Blockers/gaps:** None.

## Step 3: Wire Replacement Into site.yml
- **Status:** done
- **Result:** Added the `Replace existing OpenBao deployment when requested`
  play after target/connectivity validation and before normal convergence.
- **Files modified:**
  - `playbooks/site.yml`
- **Decisions made:** None.
- **Blockers/gaps:** None.

## Step 4: Guard upgrade.yml
- **Status:** done
- **Result:** Added an early upgrade assertion that refuses
  `openbao_replace_existing=true` and points operators to `playbooks/site.yml`.
- **Files modified:**
  - `playbooks/upgrade.yml`
- **Decisions made:** None.
- **Blockers/gaps:** None.

## Step 5: Document Behavior
- **Status:** done
- **Result:** Documented the replace setting, site playbook command,
  every-run destructive behavior, deleted managed footprint, and preserved
  external inputs/OS basics.
- **Files modified:**
  - `README.md`
  - `docs/variables.md`
- **Decisions made:** None.
- **Blockers/gaps:** None.

## Test/Lab Track: Initial Parallel Attempt
- **Status:** blocked
- **Result:** The parallel validation subagent reported a gap because
  implementation/docs were not yet visible in its workspace.
- **Blockers/gaps:** Validation must be rerun after implementation is integrated.

## Validation Fixes
- **Status:** done
- **Result:** The integrated lab surfaced three issues; all were fixed before
  final validation.
- **Files modified:**
  - `lab/vars.yml`
  - `roles/openbao_common/tasks/replace_existing.yml`
- **Decisions made:**
  - Made the Docker lab profile explicit for bootstrap mode so production
    `group_vars/rhel10/main.yml` node-subCA and unmanaged-hosts settings do not
    leak into lab validation.
  - Cleaned `openbao_data_dir` contents instead of deleting the data directory
    itself, because the Docker lab has a mounted native ACME cache at
    `/var/lib/openbao/certmagic`.
  - Cleaned mounted native ACME cache contents while preserving only the busy
    mount directory.
  - Tightened controller artifact safety checks so replacement evaluates each
    target host's controller bootstrap TLS inputs and cannot delete or live
    inside preserved controller TLS inputs or `files/bootstrap-tls/`.
- **Blockers/gaps:** None.

## Final Validation
- **Status:** done
- **Result:** Static validation, Docker lab replacement, repeated replacement,
  normal upgrade, upgrade refusal, health, and preservation checks passed.
- **Commands run:**
  - `ansible-playbook --syntax-check playbooks/site.yml`
  - `ansible-playbook --syntax-check playbooks/upgrade.yml`
  - `ansible-inventory --graph`
  - `yamllint .`
  - `ansible-lint`
  - `git diff --check`
  - `lab/scripts/openbao-lab-generate-inputs.sh`
  - `docker compose -f lab/compose.yml up -d --build`
  - `lab/scripts/openbao-lab-reset.sh --all --build`
  - `lab/scripts/openbao-lab-playbook.sh site`
  - `lab/scripts/openbao-lab-playbook.sh site -e openbao_replace_existing=true`
  - `lab/scripts/openbao-lab-playbook.sh site -e openbao_replace_existing=true`
  - `ansible -i inventory/docker-rhel10.ini rhel10 --private-key secure-artifacts/lab/ssh/id_ed25519 -b -m file -a 'path=/var/lib/openbao/certmagic/replacement-sentinel state=touch mode=0600 owner=openbao group=openbao'`
  - `lab/scripts/openbao-lab-playbook.sh site -e openbao_replace_existing=true`
  - `ansible -i inventory/docker-rhel10.ini rhel10 --private-key secure-artifacts/lab/ssh/id_ed25519 -b -m stat -a 'path=/var/lib/openbao/certmagic/replacement-sentinel'`
  - `lab/scripts/openbao-lab-playbook.sh upgrade -e openbao_replace_existing=true`
  - `lab/scripts/openbao-lab-playbook.sh upgrade`
  - `curl --resolve bao.lab.local:8443:127.0.0.1 --cacert secure-artifacts/lab/ca/root-ca.pem https://bao.lab.local:8443/v1/sys/health`
  - `ansible -i inventory/docker-rhel10.ini rhel10 --private-key secure-artifacts/lab/ssh/id_ed25519 -m stat -a 'path=/etc/openbao.d/tls/openbao.fullchain.pem'`
  - `ansible -i inventory/docker-rhel10.ini rhel10 --private-key secure-artifacts/lab/ssh/id_ed25519 -m stat -a 'path=/etc/openbao.d/tls/openbao.key.pem'`
- **Expected failure:** `lab/scripts/openbao-lab-playbook.sh upgrade -e
  openbao_replace_existing=true` failed early at the new refusal assertion with
  the intended message.
- **Blockers/gaps:** None.
