#!/bin/bash

set -e

echo "=== Vault Database Secrets Engine Setup ==="

# Set Vault address
export VAULT_ADDR="http://localhost:8200"

# Check if Vault is accessible
echo "[+] Checking Vault status..."
vault status

# Login with root token (assuming you have the token)
echo "[+] Please enter your Vault root token:"
read -s ROOT_TOKEN
export VAULT_TOKEN=$ROOT_TOKEN

# Verify authentication
echo "[+] Verifying authentication..."
vault token lookup

# Enable database secrets engine
echo "[+] Enabling database secrets engine..."
vault secrets enable database

# Verify it's enabled
echo "[+] Checking enabled secrets engines..."
vault secrets list

# Configure database connection
echo "[+] Configuring PostgreSQL database connection..."

# First, let's check if PostgreSQL is running and accessible
echo "[+] Testing PostgreSQL connection..."
kubectl get pods -n database
kubectl get svc -n database

# Get PostgreSQL service details
PG_SERVICE=$(kubectl get svc postgres-service -n database -o jsonpath='{.spec.clusterIP}')
echo "PostgreSQL service IP: $PG_SERVICE"

# Configure Vault database connection
vault write database/config/postgres \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@postgres-service.database.svc.cluster.local:5432/testdb?sslmode=disable" \
    allowed_roles="readonly,readwrite" \
    username="postgres" \
    password="initialpassword123"

echo "[+] Database connection configured. Testing connection..."
vault read database/config/postgres

# Create readonly role
echo "[+] Creating readonly database role..."
vault write database/roles/readonly \
    db_name=postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Create readwrite role  
echo "[+] Creating readwrite database role..."
vault write database/roles/readwrite \
    db_name=postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Test dynamic credential generation
echo "[+] Testing dynamic credential generation..."
echo "Generating readonly credentials:"
vault read database/creds/readonly

echo "Generating readwrite credentials:"
vault read database/creds/readwrite

echo "[+] Database secrets engine setup completed successfully!"

# Show all available roles
echo "[+] Available database roles:"
vault list database/roles

echo ""
echo "=== Setup Summary ==="
echo "✅ Database secrets engine enabled"
echo "✅ PostgreSQL connection configured"
echo "✅ Readonly and readwrite roles created"
echo "✅ Dynamic credential generation tested"
echo ""
echo "You can now generate database credentials using:"
echo "  vault read database/creds/readonly"
echo "  vault read database/creds/readwrite"