#!/bin/bash

VAULT_NAMESPACE="vault"
VAULT_SERVICE="vault-service"
VAULT_PORT="8200"
KEYS_FILE="$HOME/vault-secrets-research/vault-init-keys.txt"

if [ ! -f "$KEYS_FILE" ]; then
    echo "Error: Vault keys file not found at $KEYS_FILE"
    exit 1
fi

# Clean up any existing port forwards
echo "Cleaning up existing port forwards..."
sudo lsof -ti:$VAULT_PORT | xargs -r kill -9 2>/dev/null
sleep 3

# Extract unseal keys
UNSEAL_KEY_1=$(grep 'Unseal Key 1:' $KEYS_FILE | awk '{print $NF}')
UNSEAL_KEY_2=$(grep 'Unseal Key 2:' $KEYS_FILE | awk '{print $NF}')
UNSEAL_KEY_3=$(grep 'Unseal Key 3:' $KEYS_FILE | awk '{print $NF}')

echo "Starting port forward..."
kubectl port-forward svc/$VAULT_SERVICE $VAULT_PORT:$VAULT_PORT -n $VAULT_NAMESPACE &
PF_PID=$!

sleep 15

export VAULT_ADDR="http://localhost:$VAULT_PORT"

# Check if Vault is already unsealed
echo "Checking Vault status..."
SEALED_STATUS=$(vault status 2>/dev/null | grep "Sealed" | awk '{print $2}')

if [ "$SEALED_STATUS" = "false" ]; then
    echo "Vault is already unsealed!"
else
    echo "Unsealing Vault..."
    vault operator unseal $UNSEAL_KEY_1
    vault operator unseal $UNSEAL_KEY_2  
    vault operator unseal $UNSEAL_KEY_3
    echo "Vault unsealed successfully!"
fi

echo "Final Vault status:"
vault status

echo "Port forward PID: $PF_PID"
echo "To stop port forward: kill $PF_PID"
echo "To keep working with Vault, leave this terminal open"
