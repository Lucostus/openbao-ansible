#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  openbao-build-subca-chain.sh --subca-cert PATH --issuer-cert PATH --out PATH

Build a PEM chain file for openbao_node_subca_chain_file. The output contains:

  subCA certificate
  issuer/root certificate bundle

Options:
  --subca-cert PATH    PEM subCA certificate used by openbao_node_subca_cert_file.
  --issuer-cert PATH   PEM parent/root CA certificate or issuer bundle.
  --out PATH           Output PEM chain file path.
  --mode MODE          Output mode. Default: 0644.
  --owner OWNER        Optional output owner.
  --group GROUP        Optional output group.
  -h, --help           Show this help.

Example:
  sudo scripts/openbao-build-subca-chain.sh \
    --subca-cert /usr/local/lib/openbao/subCA-example.at.cer \
    --issuer-cert /etc/pki/ca-trust/source/anchors/example-root.pem \
    --out /usr/local/lib/openbao/subCA-example.at-chain.pem
USAGE
}

subca_cert=""
issuer_cert=""
out_file=""
out_mode="0644"
out_owner=""
out_group=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subca-cert)
      subca_cert="${2:-}"
      shift 2
      ;;
    --issuer-cert)
      issuer_cert="${2:-}"
      shift 2
      ;;
    --out)
      out_file="${2:-}"
      shift 2
      ;;
    --mode)
      out_mode="${2:-}"
      shift 2
      ;;
    --owner)
      out_owner="${2:-}"
      shift 2
      ;;
    --group)
      out_group="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$subca_cert" || -z "$issuer_cert" || -z "$out_file" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -r "$subca_cert" ]]; then
  printf 'subCA certificate is not readable: %s\n' "$subca_cert" >&2
  exit 1
fi

if [[ ! -r "$issuer_cert" ]]; then
  printf 'issuer certificate bundle is not readable: %s\n' "$issuer_cert" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

subca_only="${tmpdir}/subca.pem"
chain_candidate="${tmpdir}/chain.pem"

awk '
  /-----BEGIN CERTIFICATE-----/ { cert_index++ }
  cert_index == 1 { print }
  /-----END CERTIFICATE-----/ && cert_index == 1 { exit }
' "$subca_cert" > "$subca_only"

if [[ ! -s "$subca_only" ]]; then
  printf 'subCA certificate did not contain a PEM certificate: %s\n' "$subca_cert" >&2
  exit 1
fi

if ! openssl x509 -in "$subca_only" -noout >/dev/null 2>&1; then
  printf 'subCA certificate is not a valid PEM X.509 certificate: %s\n' "$subca_cert" >&2
  exit 1
fi

if ! openssl crl2pkcs7 -nocrl -certfile "$issuer_cert" \
  | openssl pkcs7 -print_certs -noout >/dev/null 2>&1; then
  printf 'issuer certificate bundle is not valid PEM certificate data: %s\n' "$issuer_cert" >&2
  exit 1
fi

if ! openssl verify -CAfile "$issuer_cert" "$subca_only" >/dev/null 2>&1; then
  printf 'subCA certificate does not verify against issuer bundle.\n' >&2
  printf '  subCA:  %s\n' "$subca_cert" >&2
  printf '  issuer: %s\n' "$issuer_cert" >&2
  printf 'Check that --issuer-cert contains the parent/root that issued the subCA.\n' >&2
  exit 1
fi

{
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$subca_only"
  printf '\n'
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$issuer_cert"
} > "$chain_candidate"

if [[ ! -s "$chain_candidate" ]]; then
  printf 'constructed chain is empty\n' >&2
  exit 1
fi

install_args=(-m "$out_mode")
if [[ -n "$out_owner" ]]; then
  install_args+=(-o "$out_owner")
fi
if [[ -n "$out_group" ]]; then
  install_args+=(-g "$out_group")
fi

out_dir="$(dirname "$out_file")"
if [[ ! -d "$out_dir" ]]; then
  install -d -m 0755 "$out_dir"
fi

if [[ -f "$out_file" ]] && cmp -s "$chain_candidate" "$out_file"; then
  printf 'Chain already current: %s\n' "$out_file"
else
  install "${install_args[@]}" "$chain_candidate" "$out_file"
  printf 'Wrote chain: %s\n' "$out_file"
fi

printf 'SubCA subject: %s\n' "$(openssl x509 -in "$subca_only" -noout -subject)"
printf 'SubCA issuer:  %s\n' "$(openssl x509 -in "$subca_only" -noout -issuer)"
