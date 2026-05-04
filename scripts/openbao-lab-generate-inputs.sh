#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_DIR="${ROOT_DIR}/secure-artifacts/lab/ssh"
CA_DIR="${ROOT_DIR}/secure-artifacts/lab/ca"
OPENBAO_DIR="${ROOT_DIR}/secure-artifacts/lab/openbao"
BOOTSTRAP_DIR="${ROOT_DIR}/files/bootstrap-tls"
VAULT_FILE="${ROOT_DIR}/secure-artifacts/lab/vault.yml"
STATIC_KEY_FILE="${ROOT_DIR}/secure-artifacts/lab/static-unseal.key.b64"
CA_KEY="${CA_DIR}/root-ca.key.pem"
CA_CERT="${CA_DIR}/root-ca.pem"
PUBLIC_FQDN="bao.lab.local"

hosts=(
  "rhel10-ansible-1:bao1.lab.local"
  "rhel10-ansible-2:bao2.lab.local"
  "rhel10-ansible-3:bao3.lab.local"
)

umask 077
mkdir -p "${SSH_DIR}" "${CA_DIR}" "${OPENBAO_DIR}" "${BOOTSTRAP_DIR}"

if [[ ! -f "${SSH_DIR}/id_ed25519" ]]; then
  ssh-keygen -t ed25519 -N "" -C "openbao-docker-lab" -f "${SSH_DIR}/id_ed25519" >/dev/null
fi
if [[ ! -f "${SSH_DIR}/id_ed25519.pub" ]]; then
  ssh-keygen -y -f "${SSH_DIR}/id_ed25519" > "${SSH_DIR}/id_ed25519.pub"
fi
chmod 0600 "${SSH_DIR}/id_ed25519"
chmod 0644 "${SSH_DIR}/id_ed25519.pub"

if [[ ! -f "${CA_KEY}" && ! -f "${CA_CERT}" ]]; then
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "${CA_KEY}" >/dev/null 2>&1
  openssl req -x509 -new -key "${CA_KEY}" -sha256 -days 3650 \
    -subj "/CN=OpenBao Docker Lab Root CA" \
    -out "${CA_CERT}" >/dev/null 2>&1
elif [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
  echo "Missing one of ${CA_KEY} or ${CA_CERT}; remove both to regenerate the lab CA." >&2
  exit 1
fi
chmod 0600 "${CA_KEY}"
chmod 0644 "${CA_CERT}"

if [[ ! -f "${STATIC_KEY_FILE}" ]]; then
  openssl rand -base64 32 > "${STATIC_KEY_FILE}"
fi
chmod 0600 "${STATIC_KEY_FILE}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

for item in "${hosts[@]}"; do
  inventory_host="${item%%:*}"
  node_fqdn="${item##*:}"
  key_file="${BOOTSTRAP_DIR}/${inventory_host}.key.pem"
  cert_file="${BOOTSTRAP_DIR}/${inventory_host}.fullchain.pem"
  leaf_file="${tmp_dir}/${inventory_host}.leaf.pem"
  csr_file="${tmp_dir}/${inventory_host}.csr"
  cfg_file="${tmp_dir}/${inventory_host}.cnf"

  if [[ -f "${cert_file}" && ! -f "${key_file}" ]]; then
    echo "Missing ${key_file} for existing ${cert_file}; remove the cert to regenerate both." >&2
    exit 1
  fi

  if [[ ! -f "${key_file}" ]]; then
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${key_file}" >/dev/null 2>&1
    chmod 0600 "${key_file}"
  fi

  if [[ ! -f "${cert_file}" ]]; then
    cat > "${cfg_file}" <<EOF
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${node_fqdn}
DNS.2 = ${PUBLIC_FQDN}
EOF
    openssl req -new -key "${key_file}" -subj "/CN=${node_fqdn}" -out "${csr_file}" >/dev/null 2>&1
    openssl x509 -req -in "${csr_file}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
      -days 397 -sha256 -extfile "${cfg_file}" -extensions v3_req -out "${leaf_file}" >/dev/null 2>&1
    cat "${leaf_file}" "${CA_CERT}" > "${cert_file}"
    chmod 0644 "${cert_file}"
  fi
done

vault_tmp="${tmp_dir}/vault.yml"
{
  printf '%s\n' '---'
  printf 'openbao_static_unseal_key_b64: "%s"\n' "$(tr -d '\n' < "${STATIC_KEY_FILE}")"
  printf '%s\n' 'openbao_root_ca_cert_pem: |'
  sed 's/^/  /' "${CA_CERT}"
  printf '%s\n' 'openbao_root_ca_key_pem: |'
  sed 's/^/  /' "${CA_KEY}"
} > "${vault_tmp}"

if [[ ! -f "${VAULT_FILE}" ]] || ! cmp -s "${vault_tmp}" "${VAULT_FILE}"; then
  mv "${vault_tmp}" "${VAULT_FILE}"
else
  rm -f "${vault_tmp}"
fi
chmod 0600 "${VAULT_FILE}"

cat <<EOF
Generated lab inputs:
  SSH key: ${SSH_DIR}/id_ed25519
  Lab vault vars: ${VAULT_FILE}
  Root CA: ${CA_CERT}
  Bootstrap TLS: ${BOOTSTRAP_DIR}/rhel10-ansible-*.fullchain.pem
EOF
