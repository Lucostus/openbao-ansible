#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:-}"
SSH_KEY="${ROOT_DIR}/secure-artifacts/lab/ssh/id_ed25519"
SUBCA_DIR="${ROOT_DIR}/secure-artifacts/lab/subca"
CA_DIR="${ROOT_DIR}/secure-artifacts/lab/ca"
SUBCA_CERT="${SUBCA_DIR}/subca.pem"
SUBCA_KEY="${SUBCA_DIR}/subca.key.pem"
SUBCA_CHAIN="${SUBCA_DIR}/subca-chain.pem"
ROOT_CA_CERT="${CA_DIR}/root-ca.pem"

case "${MODE}" in
  one)
    targets=("rhel10-ansible-1:2221")
    ;;
  all)
    targets=("rhel10-ansible-1:2221" "rhel10-ansible-2:2224" "rhel10-ansible-3:2225")
    ;;
  *)
    echo "Usage: $0 {one|all}" >&2
    exit 2
    ;;
esac

for required in "${SSH_KEY}" "${SUBCA_CERT}" "${SUBCA_KEY}" "${SUBCA_CHAIN}" "${ROOT_CA_CERT}"; do
  if [[ ! -f "${required}" ]]; then
    echo "Missing ${required}. Run lab/scripts/openbao-lab-generate-inputs.sh first." >&2
    exit 1
  fi
done

ssh_opts=(
  -i "${SSH_KEY}"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

for item in "${targets[@]}"; do
  host="${item%%:*}"
  port="${item##*:}"
  scp -P "${port}" "${ssh_opts[@]}" \
    "${SUBCA_CERT}" "${SUBCA_KEY}" "${SUBCA_CHAIN}" "${ROOT_CA_CERT}" \
    "ansible@127.0.0.1:/tmp/"
  ssh -p "${port}" "${ssh_opts[@]}" ansible@127.0.0.1 \
    'sudo install -d -m 0700 /etc/openbao-subca
     sudo install -d -m 0755 /etc/pki/ca-trust/source/anchors
     sudo install -o root -g root -m 0644 /tmp/subca.pem /etc/openbao-subca/subca.pem
     sudo install -o root -g root -m 0600 /tmp/subca.key.pem /etc/openbao-subca/subca.key.pem
     sudo install -o root -g root -m 0644 /tmp/subca-chain.pem /etc/openbao-subca/subca-chain.pem
     sudo install -o root -g root -m 0644 /tmp/root-ca.pem /etc/pki/ca-trust/source/anchors/openbao-lab-root-ca.pem
     rm -f /tmp/subca.pem /tmp/subca.key.pem /tmp/subca-chain.pem /tmp/root-ca.pem'
  echo "Installed lab sub-CA on ${host}."
done
