#!/bin/bash

set -e

export VAULT_ADDR="http://localhost:8200"
KEYS_FILE="$HOME/vault-secrets-research/vault-init-keys.txt"
TARGET_DB="app_test"

# Cleanup saat script selesai
cleanup() {
  echo "Stopping port-forward (PID=$PG_PID)..."
  kill $PG_PID 2>/dev/null || true
}
trap cleanup EXIT

# Cek file kunci Vault
if [ ! -f "$KEYS_FILE" ]; then
    echo "❌ Error: Vault keys file not found at $KEYS_FILE"
    exit 1
fi

# Login ke Vault
ROOT_TOKEN=$(grep 'Initial Root Token:' $KEYS_FILE | awk '{print $NF}')
vault login $ROOT_TOKEN > /dev/null

echo "🔐 Vault login success"

echo "=== 🔍 Testing Dynamic Database Credentials ==="

# Ambil kredensial readonly
echo "1️⃣ Getting readonly credentials..."
READONLY_CREDS=$(vault read -format=json database/creds/readonly)
RO_USERNAME=$(echo "$READONLY_CREDS" | jq -r '.data.username')
RO_PASSWORD=$(echo "$READONLY_CREDS" | jq -r '.data.password')

echo "✅ Readonly credentials:"
echo "   Username: $RO_USERNAME"
echo "   Password: $RO_PASSWORD"

# Ambil kredensial readwrite
echo "2️⃣ Getting readwrite credentials..."
READWRITE_CREDS=$(vault read -format=json database/creds/readwrite)
RW_USERNAME=$(echo "$READWRITE_CREDS" | jq -r '.data.username')
RW_PASSWORD=$(echo "$READWRITE_CREDS" | jq -r '.data.password')

echo "✅ Readwrite credentials:"
echo "   Username: $RW_USERNAME"
echo "   Password: $RW_PASSWORD"

# Port-forward ke PostgreSQL
echo "3️⃣ Starting port-forward to postgres-service..."
kubectl port-forward svc/postgres-service 5432:5432 -n database > /dev/null &
PG_PID=$!
sleep 5

# Tes koneksi readonly
echo "🔎 Testing readonly connection to DB: $TARGET_DB..."
PGPASSWORD=$RO_PASSWORD psql -h localhost -U $RO_USERNAME -d $TARGET_DB -c "SELECT current_user, current_database();" && \
  echo "✅ Readonly connection success" || echo "❌ Readonly connection failed"

# Tes koneksi readwrite
echo "🔎 Testing readwrite connection to DB: $TARGET_DB..."
PGPASSWORD=$RW_PASSWORD psql -h localhost -U $RW_USERNAME -d $TARGET_DB -c "SELECT current_user, current_database();" && \
  echo "✅ Readwrite connection success" || echo "❌ Readwrite connection failed"

echo "🎉 === Dynamic credentials test completed ==="
