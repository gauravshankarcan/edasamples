#!/usr/bin/env bash
# Generate demo CA, server, and client certificates for the mTLS webhook sample.
# Lab use only — do not use these credentials in production.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DE_CERT_DIR="${REPO_ROOT}/decision-environment/mtls-certs"
WORK_DIR="$(mktemp -d)"

cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

HOSTNAME="eda-webhook-mtls-activation.apps-crc.testing"
DAYS=3650

cat > "${WORK_DIR}/server-ext.cnf" <<EOF
subjectAltName = DNS:${HOSTNAME},DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

cat > "${WORK_DIR}/client-ext.cnf" <<EOF
extendedKeyUsage = clientAuth
EOF

openssl genrsa -out "${WORK_DIR}/ca.key" 4096
openssl req -new -x509 -days "${DAYS}" -key "${WORK_DIR}/ca.key" \
  -out "${WORK_DIR}/ca.crt" -subj "/CN=EDA Webhook Demo CA"

openssl genrsa -out "${WORK_DIR}/server.key" 2048
openssl req -new -key "${WORK_DIR}/server.key" -out "${WORK_DIR}/server.csr" \
  -subj "/CN=${HOSTNAME}"
openssl x509 -req -days "${DAYS}" -in "${WORK_DIR}/server.csr" \
  -CA "${WORK_DIR}/ca.crt" -CAkey "${WORK_DIR}/ca.key" -CAcreateserial \
  -out "${WORK_DIR}/server.crt" -extfile "${WORK_DIR}/server-ext.cnf"

openssl genrsa -out "${WORK_DIR}/client.key" 2048
openssl req -new -key "${WORK_DIR}/client.key" -out "${WORK_DIR}/client.csr" \
  -subj "/CN=eda-webhook-client"
openssl x509 -req -days "${DAYS}" -in "${WORK_DIR}/client.csr" \
  -CA "${WORK_DIR}/ca.crt" -CAkey "${WORK_DIR}/ca.key" -CAcreateserial \
  -out "${WORK_DIR}/client.crt" -extfile "${WORK_DIR}/client-ext.cnf"

install -d -m 0755 "${SCRIPT_DIR}" "${DE_CERT_DIR}"
install -m 0644 "${WORK_DIR}/ca.crt" "${SCRIPT_DIR}/ca.crt"
install -m 0644 "${WORK_DIR}/client.crt" "${SCRIPT_DIR}/client.crt"
install -m 0600 "${WORK_DIR}/client.key" "${SCRIPT_DIR}/client.key"
install -m 0644 "${WORK_DIR}/server.crt" "${SCRIPT_DIR}/server.crt"
install -m 0600 "${WORK_DIR}/server.key" "${SCRIPT_DIR}/server.key"
install -m 0644 "${WORK_DIR}/server.crt" "${DE_CERT_DIR}/server.crt"
install -m 0600 "${WORK_DIR}/server.key" "${DE_CERT_DIR}/server.key"
install -m 0644 "${WORK_DIR}/ca.crt" "${DE_CERT_DIR}/ca.crt"

echo "Certificates written to:"
echo "  ${SCRIPT_DIR}"
echo "  ${DE_CERT_DIR}"
