#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/compose.openbao-lab.yml"
OPENBAO_ARTIFACT_DIR="${ROOT_DIR}/secure-artifacts/lab/openbao"
LAB_INPUT_DIR="${ROOT_DIR}/secure-artifacts/lab"
BOOTSTRAP_DIR="${ROOT_DIR}/files/bootstrap-tls"

remove_inputs=false
start_lab=false
build_lab=false

usage() {
  cat <<EOF
Usage: $0 [--all] [--start] [--build]

Resets the local OpenBao Docker lab.

Default:
  - stop and remove lab containers
  - remove Docker volumes
  - remove controller OpenBao runtime artifacts under secure-artifacts/lab/openbao
  - keep generated SSH key, lab CA, lab vault, and bootstrap TLS files

Options:
  --all    Also remove generated lab inputs and bootstrap TLS files.
  --start  Start the lab containers again after reset.
  --build  Rebuild images when starting; implies --start.
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      remove_inputs=true
      ;;
    --start)
      start_lab=true
      ;;
    --build)
      start_lab=true
      build_lab=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "${ROOT_DIR}"

docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans
rm -rf "${OPENBAO_ARTIFACT_DIR}"

if [[ "${remove_inputs}" == true ]]; then
  rm -rf "${LAB_INPUT_DIR}"
  rm -f \
    "${BOOTSTRAP_DIR}/rhel10-ansible-1.fullchain.pem" \
    "${BOOTSTRAP_DIR}/rhel10-ansible-1.key.pem" \
    "${BOOTSTRAP_DIR}/rhel10-ansible-2.fullchain.pem" \
    "${BOOTSTRAP_DIR}/rhel10-ansible-2.key.pem" \
    "${BOOTSTRAP_DIR}/rhel10-ansible-3.fullchain.pem" \
    "${BOOTSTRAP_DIR}/rhel10-ansible-3.key.pem"
  "${ROOT_DIR}/scripts/openbao-lab-generate-inputs.sh"
fi

if [[ "${start_lab}" == true ]]; then
  if [[ "${build_lab}" == true ]]; then
    docker compose -f "${COMPOSE_FILE}" up -d --build
  else
    docker compose -f "${COMPOSE_FILE}" up -d
  fi
fi

cat <<EOF
OpenBao Docker lab reset complete.

Next setup command:
  scripts/openbao-lab-playbook.sh site
EOF
