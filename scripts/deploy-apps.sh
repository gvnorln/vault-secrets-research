#!/bin/bash

KEYS_FILE="$HOME/vault-secrets-research/vault-init-keys.txt"

echo "=== Deploying Test Applications ==="

# Get root token from vault keys
if [ -f "$KEYS_FILE" ]; then
    ROOT_TOKEN=$(grep 'Initial Root Token:' $KEYS_FILE | awk '{print $NF}')
    echo "Root token found"
else
    echo "Error: Vault keys file not found at $KEYS_FILE"
    exit 1
fi

# Deploy static secrets app
echo "Deploying static secrets app..."
kubectl apply -f k8s/app/static-secrets-deployment.yaml

# Replace token in vault secrets deployment and deploy
echo "Deploying vault secrets app..."
sed "s/REPLACE_WITH_ROOT_TOKEN/$ROOT_TOKEN/g" k8s/app/vault-secrets-deployment.yaml | kubectl apply -f -

# Wait for deployments
echo "Waiting for applications to be ready..."
kubectl wait --for=condition=available deployment/static-secrets-app --timeout=300s
kubectl wait --for=condition=available deployment/vault-secrets-app --timeout=300s

echo "=== Applications deployed successfully ==="
kubectl get pods -l app=static-secrets-app
kubectl get pods -l app=vault-secrets-app
