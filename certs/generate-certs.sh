#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Generating CA key and certificate..."
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/CN=NATS-Local-CA"

echo "Generating server key and CSR..."
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/CN=nats-server"

cat > server-ext.cnf << EOF
[SAN]
subjectAltName=DNS:nats-server,DNS:localhost,IP:127.0.0.1
EOF

echo "Signing server certificate with CA..."
openssl x509 -req -days 3650 \
  -in server.csr \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -out server.crt \
  -extfile server-ext.cnf \
  -extensions SAN

rm server.csr server-ext.cnf
echo "Done. Files: ca.crt, server.crt, server.key"
