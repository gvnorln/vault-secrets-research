#!/bin/bash

echo "=== Testing Dynamic Secrets ==="

# Step 1: Cleanup
echo "[+] Cleaning up..."
./scripts/vault-helper.sh cleanup
sleep 3

# Step 2: Start Vault (unseal)
echo "[+] Starting Vault and unsealing..."
./scripts/vault-unseal.sh
VAULT_PID=$!
sleep 20

# Step 3: Login to Vault
echo "[+] Logging in to Vault..."
ROOT_TOKEN=$(grep 'Initial Root Token:' vault-init-keys.txt | awk '{print $NF}')
export VAULT_ADDR="http://localhost:8200"
vault login $ROOT_TOKEN

# Step 4: List Secrets Engines
echo "[+] Testing secrets engines:"
vault secrets list

# Step 5: Test dynamic database credentials
echo "[+] Testing database credentials:"
./scripts/test/test-dynamic-db.sh
# Step 6: Check PostgreSQL connection
echo "[+] Checking PostgreSQL connection..."
kubectl get pods -n database
kubectl get svc -n database
# Step 7: Verify database roles
echo "[+] Verifying database roles..."
kubectl exec -it $(kubectl get pod -l app=postgres -n database -o jsonpath='{.items[0].metadata.name}') -n database -- psql -U postgres -c "\du"

# Done
echo "=== Final Verification Step Completed ==="
