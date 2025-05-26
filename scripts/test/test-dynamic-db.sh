#!/bin/bash

export VAULT_ADDR="http://localhost:8200"
KEYS_FILE="$HOME/vault-secrets-research/vault-init-keys.txt"

if [ ! -f "$KEYS_FILE" ]; then
    echo "Error: Vault keys file not found"
    exit 1
fi

# Login to Vault
ROOT_TOKEN=$(grep 'Initial Root Token:' $KEYS_FILE | awk '{print $NF}')
vault login $ROOT_TOKEN > /dev/null

echo "=== Testing Dynamic Database Credentials ==="

# Get readonly credentials
echo "1. Getting readonly credentials..."
READONLY_CREDS=$(vault read -format=json database/creds/readonly)
RO_USERNAME=$(echo $READONLY_CREDS | jq -r '.data.username')
RO_PASSWORD=$(echo $READONLY_CREDS | jq -r '.data.password')

echo "Readonly credentials:"
echo "  Username: $RO_USERNAME"
echo "  Password: $RO_PASSWORD"

# Get readwrite credentials  
echo "2. Getting readwrite credentials..."
READWRITE_CREDS=$(vault read -format=json database/creds/readwrite)
RW_USERNAME=$(echo $READWRITE_CREDS | jq -r '.data.username')
RW_PASSWORD=$(echo $READWRITE_CREDS | jq -r '.data.password')

echo "Readwrite credentials:"
echo "  Username: $RW_USERNAME" 
echo "  Password: $RW_PASSWORD"

# Test database connection (need jq installed)
echo "3. Testing database connections..."

# Port forward to postgres (in background)
kubectl port-forward svc/postgres-service 5432:5432 -n database &
PG_PID=$!
sleep 5

# Test readonly connection
echo "Testing readonly connection..."
PGPASSWORD=$RO_PASSWORD psql -h localhost -U $RO_USERNAME -d testdb -c "SELECT current_user, current_database();" 2>/dev/null

# Test readwrite connection
echo "Testing readwrite connection..."
PGPASSWORD=$RW_PASSWORD psql -h localhost -U $RW_USERNAME -d testdb -c "SELECT current_user, current_database();" 2>/dev/null

# Cleanup
kill $PG_PID 2>/dev/null

echo "=== Dynamic credentials test completed ==="
