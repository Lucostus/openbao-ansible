#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAYBOOK_NAME="${1:-}"

case "${PLAYBOOK_NAME}" in
  site|upgrade)
    shift
    ;;
  *)
    echo "Usage: $0 {site|upgrade} [ansible-playbook args...]" >&2
    exit 2
    ;;
esac

SSH_KEY="${ROOT_DIR}/secure-artifacts/lab/ssh/id_ed25519"
VAULT_FILE="${ROOT_DIR}/secure-artifacts/lab/vault.yml"

if [[ ! -f "${SSH_KEY}" || ! -f "${VAULT_FILE}" ]]; then
  echo "Missing lab inputs. Run lab/scripts/openbao-lab-generate-inputs.sh first." >&2
  exit 1
fi

cd "${ROOT_DIR}"
exec ansible-playbook \
  -i inventory/docker-rhel10.ini \
  --private-key "${SSH_KEY}" \
  -e @lab/vars.yml \
  -e "openbao_secret_vars_file=${VAULT_FILE}" \
  "playbooks/${PLAYBOOK_NAME}.yml" \
  "$@"
